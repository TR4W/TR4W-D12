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
unit uEditQSO;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

(* ---------- I M P O R T A N T    Form is in the RES file -------------------*)
interface

uses
  //  shellapi,
  uCTYDAT,
  uMP3Recorder,
  uStations,
  WinSock2,
  uNet,
  TF,
  VC,
  //Country9,
  Windows,
  uCallSignRoutines,
  utils_file,
  LogCW,
  uTotal,
  Tree,
  LOGSUBS1,
  LOGSUBS2,
  LogDupe,
  LogStuff,
  uCommctrl,
  ZoneCont,
  LogK1EA,
  LogEdit,
  LogWind,
  Messages
  ,
  uTR4WStrings,
  uAnsiStr;

procedure OpenEditQSOWindow(Parent: HWND);

// THE FOUR HALVES THE LCL FORM CALLS BACK INTO (Phase 5, 2026-08-19).
// The behaviour stayed in this unit -- it owns the log record and the
// ContestExchange it is editing -- and src\ui\lcl\uEditQSOForm.pas is
// presentation plus the id-to-control shim. That split is why the save
// function below still reads field by field, by the SAME control ids.
function  LoadQSOIntoEditForm: boolean;
procedure CallsignChangedInEditForm;
procedure PlayMP3ForEditedQSO;
procedure AfterEditQSOClosed;
function SaveQSOToEditableLog: boolean;
function CheckSystemTimeRecord(Time: TQSOTime): boolean;
procedure ShowNote(CE: ContestExchange);
//procedure ShowSysMonthCal32(show: integer);

const
  FLD_FREQUENCY = 106;
  FLD_RSTRECEIVED = 108;
  FLD_BAND = 112;
  FLD_MODE = 113;
  FLD_RADIO = 114;
  FLD_COUNTRYNAME = 115;
  FLD_NUMBERSEND = 116;

  FLD_COMPUTERID = 117;
  FLD_CALLSIGN = 118;
  FLD_RSTSEND = 119;
  FLD_TENTENNUM = 120;
  FLD_PREFECTURE = 121;
  FLD_QSOPOINTS = 122;
  FLD_XQSO = 170;       // Issue #750 -- X-QSO checkbox (not claimed for Cabrillo)

  FLD_SAVE_BUTTON = 123;
  FLD_CANCEL_BUTTON = 124;
  FLD_PLAY_BUTTON = 201;

  FLD_SAP = 125;

  FLD_ZONEMULT = 126;
  FLD_PREFIXMULT = 127;
  FLD_DOMESTICMULT = 129;
  FLD_DUPE = 130;
  FLD_DELETED = 132;
  FLD_CLASS = 133;
  FLD_AGE = 136;
  FLD_CHAPTER = 138;
  FLD_CHECK = 141;
  FLD_PRECEDENCE = 142;
  FLD_INHIBITMULTS = 143;
  FLD_POWER = 144;
  FLD_NUMBERRECEIVED = 146;
  FLD_DXQTH = 148;
  FLD_DOMMULTQTH = 150;
  FLD_PREFIX = 152;
  FLD_ZONE = 154;
  FLD_DXMULT = 156;
  FLD_NAME = 158;
  FLD_QTHSTRING = 160;
  FLD_POSTALCODE = 162;
  FLD_OPERATOR = 167;
  {
    FLD_HOUR                              = 180;
    FLD_MINUTE                            = 181;
    FLD_SECOND                            = 182;
    FLD_DAY                               = 183;
    FLD_MONTH                             = 184;
    FLD_YEAR                              = 185;
  }

  //  SETLIMITTEXTARRAY           : array[0..3] of integer;
var
  EditableQSORXData: ContestExchange;
  //const  eqMultsArray                          : array[1..5] of PBoolean = (nil, nil, nil, nil, nil);

implementation
uses
   uPlatformProcess,   // RunProgram / RunWindowsUtility -- the only launchers
  SysUtils,         // SystemTimeToDateTime / DateTimeToSystemTime
  MainUnit,
  uLogEdit,
  uEditQSOForm,     // the LCL form, and the id-to-control accessors
  uHamScore,         // Issue #783 -- HamScoreOnEdit / HamScoreOnDelete hooks
  uConfigValues;

// Fills the form from the log record under the edit cursor.
//
// Answers FALSE for every record this dialog refuses to edit -- a note, a
// skipped QSO, anything that is not rkQSO, and a log that will not open. The
// Win32 version expressed each of those as `goto 1` into its WM_CLOSE arm; the
// form closes on False.
function LoadQSOIntoEditForm: boolean;
var
  IndexInMap: integer;
  lpNumberOfBytesRead: Cardinal;
  bt: BandType;
  extMode: ExtendedModeType;
  TempSysTime: SYSTEMTIME;
begin
   Result := False;

   IndexInMap := IndexOfItemInLogForEdit;

   if not OpenLogFile then
      begin
      Exit;
      end;

   tSetFilePointer(IndexInMap, FILE_BEGIN);
   Windows.ReadFile(LogHandle, EditableQSORXData, SizeOf(ContestExchange),
     lpNumberOfBytesRead, nil);
   CloseLogFile;

   if EditableQSORXData.ceRecordKind = rkNote then
      begin
      ShowNote(EditableQSORXData);
      Exit;
      end;

   if EditableQSORXData.MP3Record then
      begin
      if FileExists(DeleteSlashes(MakeMP3Filename(@EditableQSORXData))) then
         begin
         EditQSOSetEnabled(FLD_PLAY_BUTTON, True);
         end;
      end;

   if (EditableQSORXData.ceQSO_Skiped) or
      (EditableQSORXData.ceRecordKind <> rkQSO) then
      begin
      Exit;
      end;

   // EM_SETLIMITTEXT is gone: every one of those limits is now MaxLength in the
   // .lfm, set from the same numbers. The loop that sent it to ids 180..184 went
   // with it -- only 180 exists in the template, and it is a date picker, so
   // four of those five sends went to no window at all and the fifth to a
   // control that has no such message.

   EditQSOSetText(FLD_CALLSIGN, string(EditableQSORXData.Callsign));

   for bt := Band160 to NoBand do
      begin
      EditQSOAddItem(FLD_BAND, string(BandStringsArrayWithOutSpaces[bt]));
      end;

   if not SO2R_Swap then
      begin
      EditQSOSetItemIndex(FLD_BAND, Ord(EditableQSORXData.Band));
      end
   else
      begin
      EditQSOSetItemIndex(FLD_BAND, Ord(inAct_Band));
      end;

   for extMode := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      EditQSOAddItem(FLD_MODE, string(ExtendedModeStringArray[extMode]));
      end;

   // A record written before extended modes existed carries eNoMode; widen it
   // from the plain mode so the combo has something to select.
   if EditableQSORXData.ExtMode = eNoMode then
      begin
      case EditableQSORXData.Mode of
        CW:      EditableQSORXData.ExtMode := eCW;
        Phone:   EditableQSORXData.ExtMode := eSSB;
        Digital: EditableQSORXData.ExtMode := eRTTY;
        FM:      EditableQSORXData.ExtMode := eFM;
        end;
      end;

   EditQSOSetItemIndex(FLD_MODE, Ord(EditableQSORXData.ExtMode));

   if not SO2R_Swap then
      begin
      EditQSOSetInt(FLD_FREQUENCY, EditableQSORXData.Frequency);
      end
   else
      begin
      EditQSOSetInt(FLD_FREQUENCY, inAct_Freq);
      end;

   // THE DATE FIELD, AND WHY IT IS NOW ONE LINE.
   //
   // This was DTM_SETFORMAT plus DTM_SETSYSTEMTIME against a SysDateTimePick32,
   // and it carried the defect NY4I found on the bench (2026-08-18): the format
   // message resolved to the ANSI DTM_SETFORMATA while PChar under FPC is
   // PWideChar, so the control read the UTF-16 bytes of 'HH:mm dd-MM-yyyy' as
   // ANSI -- 'H', #0 -- and the #0 ended it. The effective format was a bare
   // hour, so a QSO logged at 23:46 showed "23" in the date field, in a dialog
   // that writes back to the log. A TDateTimePicker takes a TDateTime; there is
   // no format string to get wrong and no message constant to bind to the wrong
   // width.
   Windows.ZeroMemory(@TempSysTime, SizeOf(TempSysTime));
   TempSysTime.wYear   := EditableQSORXData.tSysTime.qtYear + 2000;
   TempSysTime.wMonth  := EditableQSORXData.tSysTime.qtMonth;
   TempSysTime.wDay    := EditableQSORXData.tSysTime.qtDay;
   TempSysTime.wHour   := EditableQSORXData.tSysTime.qtHour;
   TempSysTime.wMinute := EditableQSORXData.tSysTime.qtMinute;
   TempSysTime.wSecond := EditableQSORXData.tSysTime.qtSecond;
   EditQSOSetDateTime(SystemTimeToDateTime(TempSysTime));

   EditQSOSetText(FLD_COMPUTERID, string(EditableQSORXData.ceComputerID));
   EditQSOSetInt(FLD_QSOPOINTS, EditableQSORXData.QSOPoints);

   if EditableQSORXData.Age <> 0 then
      begin
      EditQSOSetInt(FLD_AGE, EditableQSORXData.Age);
      end;

   if EditableQSORXData.Check <> 0 then
      begin
      EditQSOSetInt(FLD_CHECK, EditableQSORXData.Check);
      end;

   EditQSOSetText(FLD_CHAPTER, string(EditableQSORXData.Chapter));
   EditQSOSetText(FLD_CLASS,   string(EditableQSORXData.ceClass));

   EditQSOSetCheck(FLD_SAP,     EditableQSORXData.ceSearchAndPounce);
   EditQSOSetCheck(FLD_DELETED, EditableQSORXData.ceQSO_Deleted);
   EditQSOSetCheck(FLD_DUPE,    EditableQSORXData.ceDupe);

   // Issue #750: X-QSO. Read back on save in the matching block below.
   EditQSOSetCheck(FLD_XQSO, EditableQSORXData.ceXQSO);

   EditQSOSetInt(FLD_NUMBERSEND, EditableQSORXData.NumberSent);

   if EditableQSORXData.NumberReceived <> -1 then
      begin
      EditQSOSetInt(FLD_NUMBERRECEIVED, EditableQSORXData.NumberReceived);
      end;

   EditQSOSetText(FLD_DXQTH,      string(EditableQSORXData.DXQTH));
   EditQSOSetText(FLD_DOMMULTQTH, string(EditableQSORXData.DomMultQTH));
   EditQSOSetText(FLD_PREFIX,     string(EditableQSORXData.Prefix));

   if EditableQSORXData.Zone <> DUMMYZONE then
      begin
      EditQSOSetInt(FLD_ZONE, EditableQSORXData.Zone);
      end;

   EditQSOSetText(FLD_NAME,      string(EditableQSORXData.Name));
   EditQSOSetText(FLD_QTHSTRING, string(EditableQSORXData.QTHString));
   EditQSOSetText(FLD_POWER,     string(EditableQSORXData.Power));
   EditQSOSetText(FLD_PRECEDENCE, string(EditableQSORXData.Precedence));

   if EditableQSORXData.Prefecture <> MAXBYTE then
      begin
      EditQSOSetInt(FLD_PREFECTURE, EditableQSORXData.Prefecture);
      end;

   if EditableQSORXData.TenTenNum <> MAXWORD then
      begin
      EditQSOSetInt(FLD_TENTENNUM, EditableQSORXData.TenTenNum);
      end;

   EditQSOSetInt(FLD_RSTSEND,     EditableQSORXData.RSTSent);
   EditQSOSetInt(FLD_RSTRECEIVED, EditableQSORXData.RSTReceived);

   // The five mult flags and Inhibit Mults are DISPLAY ONLY -- the save path
   // never reads them back, which is exactly what BS_CHECKBOX (rather than
   // BS_AUTOCHECKBOX) said in the template. The form greys them for that reason.
   EditQSOSetCheck(FLD_INHIBITMULTS, EditableQSORXData.InhibitMults);
   EditQSOSetCheck(FLD_DXMULT,       EditableQSORXData.DXMult);
   EditQSOSetCheck(FLD_DOMESTICMULT, EditableQSORXData.DomesticMult);
   EditQSOSetCheck(FLD_PREFIXMULT,   EditableQSORXData.PrefixMult);
   EditQSOSetCheck(FLD_ZONEMULT,     EditableQSORXData.ZoneMult);

   if EditableQSORXData.ceRadio = RadioTwo then
      begin
      EditQSOSetText(FLD_RADIO, 'RADIO TWO');
      end;

   EditQSOSetText(FLD_OPERATOR, string(EditableQSORXData.ceOperator));  // Issue 601 NY4I

   Result := True;
end;

// The country, prefix and DX QTH follow the callsign as it is typed.  This was
// the EN_CHANGE arm, and it ran on a PROGRAMMATIC SetDlgItemText too -- which is
// why LoadQSOIntoEditForm sets the callsign first and the prefix and DX QTH
// afterwards, so the explicit values win. Keep that order.
procedure CallsignChangedInEditForm;
var
  TempString: ShortString;
begin
   TempString := EditQSOGetText(FLD_CALLSIGN);

   Windows.ZeroMemory(@EditableQSORXData.QTH, SizeOf(EditableQSORXData.QTH));
   ctyLocateCall(TempString, EditableQSORXData.QTH);

   if DoingPrefixMults then
      begin
      Windows.ZeroMemory(@EditableQSORXData.Prefix,
        SizeOf(EditableQSORXData.Prefix));
      SetPrefix(EditableQSORXData);
      EditQSOSetText(FLD_PREFIX, string(EditableQSORXData.Prefix));
      end;

   EditQSOSetText(FLD_COUNTRYNAME,
     string(ctyGetCountryNamePchar(ctyGetCountry(TempString))));

   if ActiveDXMult <> NoDXMults then
      begin
      EditQSOSetText(FLD_DXQTH, string(EditableQSORXData.QTH.CountryID));
      end;
end;

procedure PlayMP3ForEditedQSO;
begin
   // No player configured is not a failure -- it is a prompt to configure one,
   // which is what the Win32 arm did before it gave up.
   if Config.MP3Player[0] = #0 then
      begin
      SetCommand('MP3 PLAYER');
      Exit;
      end;

   // The operator's own player, with the file as an ARGUMENT rather than
   // pasted into a command line -- see uPlatformProcess on quoting.
   RunProgram(string(Config.MP3Player),
              [string(PAnsiChar(DeleteSlashes(MakeMP3Filename(@EditableQSORXData))))]);
end;

procedure AfterEditQSOClosed;
begin
   tCallWindowSetFocus;
end;

{
One notable thing missing from this code below is validation. A few items such as
CALLSIGN are checked but not items like QTH. I can edit a record to make the
state WC or the ARRl section WSX (both invalid). Considering we are editing
the current contest, it seems reasonable to add code to validate the edit
just like when the contact was first entered.
I will make this a seperate Issue to track it.
 } // ny4i 25 Feb 2016

function SaveQSOToEditableLog: boolean;
label
  1, 2;
var
  //  TCE                                   : ContestExchange;
  IndexInMap: integer;
  lpNumberOfBytesWritten: Cardinal;
  TempInteger: integer;
  ansiOperator: RawByteString;
  operatorLen:  integer;
  TempString: string;
  lpTranslated: boolean;
  //  TempString                            : ShortString;
  TempWord: Word;
  //  TempPointer                           : PWORD;
  TempByte: Byte;
  TempSysTime: SYSTEMTIME;
begin
  Result := True;

  // THE CONFIRMATION USED TO BE HERE, and it has moved to the two places the
  // operator can actually ask for a save -- btnSaveClick and the form's
  // OnCloseQuery (uEditQSOForm).  Reasons, in order of weight:
  //
  //   * A routine that writes 340 lines of binary into the contest log should
  //     not also be deciding whether to ask a question.  Its caller knows what
  //     the operator did; this does not.
  //   * There are now TWO ways to reach a save -- the button, and answering
  //     Yes to "Save changes?" on the way out.  Left here, the second one
  //     prompted twice for one action.
  //   * It was never guarded by whether anything had CHANGED, so it fired on a
  //     QSO nobody had touched.  In D7 that was invisible, because the Save
  //     button was only enabled once a field changed and so was unreachable on
  //     an untouched QSO.  The LCL form had lost that (it enabled Save in
  //     OnShow); with that fixed, moving the prompt out is behaviour-preserving
  //     for the button and correct for the new path.
  //
  // Config.ConfirmEditChanges still governs it -- see uEditQSOForm.

  //EditableQSORXData.QTH

  DateTimeToSystemTime(EditQSOGetDateTime, TempSysTime);

  if TempSysTime.wYear >= 2000 then
     begin
     EditableQSORXData.tSysTime.qtYear := TempSysTime.wYear - 2000;
     end;
  EditableQSORXData.tSysTime.qtMonth := TempSysTime.wMonth;
  EditableQSORXData.tSysTime.qtDay := TempSysTime.wDay;
  //Time
  EditableQSORXData.tSysTime.qtSecond := TempSysTime.wSecond;
  EditableQSORXData.tSysTime.qtMinute := TempSysTime.wMinute;
  EditableQSORXData.tSysTime.qtHour := TempSysTime.wHour;


    {Callsign}
  //  EditableQSORXData.Callsign := GetDialogItemText(eq_handle, 118);
  Windows.ZeroMemory(@EditableQSORXData.Callsign, SizeOf(CallString));
  EditableQSORXData.Callsign := EditQSOGetText(FLD_CALLSIGN);

  if not IsAGoodCall(EditableQSORXData.Callsign) then
     begin
     showwarning(TC_CHECKCALLSIGN);
     Result := False;
     Exit;
     end;

  //  LocateCall(EditableQSORXData.Callsign, EditableQSORXData.QTH, true);
  if ActiveDXMult <> NoDXMults then
     begin
     ZeroMemory(@EditableQSORXData.DXQTH, SizeOf(EditableQSORXData.DXQTH));
     EditableQSORXData.DXQTH := EditableQSORXData.QTH.CountryID;
     end;

  //   Sheet.SetMultFlags(EditableQSORXData);
  CalculateQSOPoints(EditableQSORXData);

  {Band}
  if SO2R_Swap then
     begin
     EditableQSORXData.Band := Inact_Band
     end
  else
     begin
     EditableQSORXData.Band := BandType(EditQSOGetItemIndex(FLD_BAND));
     end;

  {Mode}
  // Mode has an extendedMode so grab it and convert it to a modeType and store both
  EditableQSORXData.ExtMode := ExtendedModeType(EditQSOGetItemIndex(FLD_MODE));
  EditableQSORXData.Mode := GetModeFromExtendedMode(EditableQSORXData.ExtMode);

  {Frequency}
  if SO2R_Swap then
     begin
     lpNumberOfBytesWritten := inact_freq
     end
  else
     begin
     lpNumberOfBytesWritten := Cardinal(EditQSOGetInt(FLD_FREQUENCY, lpTranslated));
     end;
  //if lpNumberOfBytesWritten < MAXDWORD then
  ZeroMemory(@EditableQSORXData.Frequency, SizeOf(EditableQSORXData.Frequency));
  EditableQSORXData.Frequency := lpNumberOfBytesWritten;

  {ComputerID}
  TempString := EditQSOGetText(FLD_COMPUTERID);
  if TempString = '' then
     begin
     EditableQSORXData.ceComputerID := #0;
     end
  else
     begin
     EditableQSORXData.ceComputerID := AnsiChar(TempString[1]);
     end;
  if not (EditableQSORXData.ceComputerID in ['A'..'Z']) then
     begin
     EditableQSORXData.ceComputerID := #0;
     end;

  {Age}
  lpNumberOfBytesWritten := Cardinal(EditQSOGetInt(FLD_AGE, lpTranslated));
  if lpNumberOfBytesWritten < MAXBYTE then
     begin
     ZeroMemory(@EditableQSORXData.Age, SizeOf(EditableQSORXData.Age));
     EditableQSORXData.Age := lpNumberOfBytesWritten;
     end;

  {Chapter}
  ZeroMemory(@EditableQSORXData.Chapter, SizeOf(EditableQSORXData.Chapter));
  EditableQSORXData.Chapter := EditQSOGetText(FLD_CHAPTER);
  {Check}
  ZeroMemory(@EditableQSORXData.Check, SizeOf(EditableQSORXData.Check));
  EditableQSORXData.Check := EditQSOGetInt(FLD_CHECK, lpTranslated);
  {ClassCE}
  ZeroMemory(@EditableQSORXData.ceClass, SizeOf(EditableQSORXData.ceClass));
  EditableQSORXData.ceClass := EditQSOGetText(FLD_CLASS);

  {NumberSent}
  ZeroMemory(@EditableQSORXData.NumberSent,
    SizeOf(EditableQSORXData.NumberSent));
  EditableQSORXData.NumberSent := EditQSOGetInt(FLD_NUMBERSEND, lpTranslated);

  {NumberReceived}
  TempInteger := EditQSOGetInt(FLD_NUMBERRECEIVED, lpTranslated);
  if lpTranslated then
     begin
     ZeroMemory(@EditableQSORXData.NumberReceived,
       SizeOf(EditableQSORXData.NumberReceived));
     EditableQSORXData.NumberReceived := TempInteger;
     end;

  {DomMultQTH}
//  EditableQSORXData.DomMultQTH := GetDialogItemText(eq_handle, FLD_DOMMULTQTH);
//  EditableQSORXData.DomMultQTH[0] := AnsiChar(Windows.GetDlgItemTextA(eq_handle, FLD_DOMMULTQTH, @EditableQSORXData.DomMultQTH[1], SizeOf(EditableQSORXData.DomMultQTH) - 1));

  {Prefix}
  ZeroMemory(@EditableQSORXData.Prefix, SizeOf(EditableQSORXData.Prefix));
  EditableQSORXData.Prefix := EditQSOGetText(FLD_PREFIX);

  {Zone}

  TempByte := Byte(EditQSOGetInt(FLD_ZONE, lpTranslated));
  if lpTranslated then
     begin
     ZeroMemory(@EditableQSORXData.Zone, SizeOf(EditableQSORXData.Zone));
     EditableQSORXData.Zone := TempByte
     end
  else
     begin
     if TempByte = 0 then
        begin
        ZeroMemory(@EditableQSORXData.Zone, SizeOf(EditableQSORXData.Zone));
        EditableQSORXData.Zone := DUMMYZONE;
        end;
     end;

  {Name}
  ZeroMemory(@EditableQSORXData.Name, SizeOf(EditableQSORXData.Name));
  EditableQSORXData.Name := EditQSOGetText(FLD_NAME);

  {QTHString}
  // The next line was commented out - so test this well ny4i Issue112
  Windows.ZeroMemory(@EditableQSORXData.QTHString,
    SizeOf(EditableQSORXData.QTHString));
  EditableQSORXData.QTHString := EditQSOGetText(FLD_QTHSTRING);
  if DoingDomesticMults then
     begin
     FoundDomesticQTH(EditableQSORXData);
       {then showwarning(TC_IMPROPERDOMESITCQTH)}
     ;
     end;

  {Postal Code}
//  EditableQSORXData.PostalCode := GetDialogItemText(eq_handle, FLD_POSTALCODE);
  //windows.GetDlgItemTextA(eq_handle,FLD_POSTALCODE,EditableQSORXData.PostalCode,sizeof(PostalCodeString));

  {Power}
  ZeroMemory(@EditableQSORXData.Power, SizeOf(EditableQSORXData.Power));
  EditableQSORXData.Power :=
    EditQSOGetText(FLD_POWER);

  {Precedence}
  TempString := EditQSOGetText(FLD_PRECEDENCE);
  ZeroMemory(@EditableQSORXData.Precedence,
    SizeOf(EditableQSORXData.Precedence));
  if TempString <> '' then
     begin
     EditableQSORXData.Precedence := AnsiChar(TempString[1]);
     end;

  {Prefecture}
  TempByte := Byte(EditQSOGetInt(FLD_PREFECTURE, lpTranslated));
  if lpTranslated then
     begin
     ZeroMemory(@EditableQSORXData.Prefecture,
       SizeOf(EditableQSORXData.Prefecture));
     EditableQSORXData.Prefecture := TempByte;
     end;

  {TenTenNum}
  TempWord := Word(EditQSOGetInt(FLD_TENTENNUM, lpTranslated));
  if lpTranslated then
     begin
     ZeroMemory(@EditableQSORXData.TenTenNum,
       SizeOf(EditableQSORXData.TenTenNum));
     EditableQSORXData.TenTenNum := TempWord;
     end;

  {RSTSent}
  TempInteger := EditQSOGetInt(FLD_RSTSEND, lpTranslated);
  if lpTranslated then
     begin
     ZeroMemory(@EditableQSORXData.RSTSent, SizeOf(EditableQSORXData.RSTSent));
     EditableQSORXData.RSTSent := TempInteger {TempWord};
     end;

  {RSTReceived}
  TempInteger := EditQSOGetInt(FLD_RSTRECEIVED, lpTranslated);
  if lpTranslated then
     begin
     ZeroMemory(@EditableQSORXData.RSTReceived,
       SizeOf(EditableQSORXData.RSTReceived));
     EditableQSORXData.RSTReceived := TempInteger {TempWord};
     end;

  {Operator}

  { AN ANSI ARRAY, WRITTEN FROM A UTF-16 STRING -- and that is how the operator
    became one letter.

    ceOperator is array[0..10] of AnsiChar. tempOperator is `string`, which
    tr4w.inc makes UnicodeString, so `sizeof(char)` here is 2 and the old Move
    copied UTF-16 code units straight into the byte array: 'NY4I' landed as
    'N',#0,'Y',#0,'4',#0,'I',#0 and read back at the first #0 as "N". NY4I,
    2026-08-28: "I changed the contact for W1SSB and it updated operator to
    just N. The sanctity of a QSO is paramount."

    The round-trip harness could not see this -- Invoke-FieldCheck proves a
    value survives the CONTROL, and this is the write to the RECORD.

    Two more faults in the three lines, both silent:
      * the zero-fill used lstrlenA of the value ALREADY there, so a shorter
        new name left the tail of the old one behind;
      * nothing bounded the copy to the array, so an operator name of 11
        characters or more wrote past it, over ceSentRST and whatever follows.

    Convert once, bound it, and leave room for the terminator. }
  ansiOperator := WinAnsi(EditQSOGetText(FLD_OPERATOR));
  FillChar(EditableQSORXData.ceOperator, SizeOf(EditableQSORXData.ceOperator), 0);
  operatorLen := Length(ansiOperator);
  if operatorLen > SizeOf(EditableQSORXData.ceOperator) - 1 then
     begin
     operatorLen := SizeOf(EditableQSORXData.ceOperator) - 1;
     end;
  if operatorLen > 0 then
     begin
     Move(ansiOperator[1], EditableQSORXData.ceOperator[0], operatorLen);
     end;
  //EditableQSORXData.ceOperator[1] := Char(Windows.GetDlgItemTextA(eq_handle,
  //  FLD_OPERATOR, @EditableQSORXData.ceOperator,
  //  Windows.lstrlen(EditableQSORXData.ceOperator) - 1));

  //EditableQSORXData.ceOperator[0] := AnsiChar(Windows.GetDlgItemTextA(eq_handle,
  //  FLD_OPERATOR, @EditableQSORXData.ceOperator[1],
   // Windows.lstrlen(EditableQSORXData.ceOperator) - 1));

  IndexInMap := IndexOfItemInLogForEdit;
  {SAP}
  EditableQSORXData.ceSearchAndPounce :=
    EditQSOGetCheck(FLD_SAP);

  {DELETED}
  EditableQSORXData.ceQSO_Deleted := EditQSOGetCheck(FLD_DELETED);

  {X-QSO -- Issue #750.  Not claimed for credit but stays in the log for
   NIL protection of the other station.  Counts for nothing else
   (multipliers, points, dupe check), and the Cabrillo export emits an
   `X-QSO:` line prefix.  ADIF export emits APP_TR4W_CLAIMEDQSO=0 so a
   round-trip preserves the flag.}
  EditableQSORXData.ceXQSO := EditQSOGetCheck(FLD_XQSO);

  // Deleted QSOs send a contactdelete only.
  // Edited (non-deleted) QSOs send a contactreplace so consumers update in place.
  if EditableQSORXData.ceQSO_Deleted then
     begin
     SendDeletedContactToUDP(EditableQSORXData);
     if Assigned(externalLogger) then
        begin
        externalLogger.DeleteQSO(EditableQSORXData);
        end;
     // Issue #783 -- HamScore RTC: send <contactdelete> next cycle.
     HamScoreOnDelete(EditableQSORXData);
     end
  else if EditableQSORXData.ceXQSO then
     begin
     // Issues #949 / #954 -- X-QSO is NOT a delete. The contact really happened,
     // so it stays in the log and the external logger and keeps the serial it
     // consumed; it is only removed from the CONTEST score. So drop it from the
     // score feeds (contactdelete to UDP + HamScore) but deliberately DO NOT
     // touch the external logger. (The serial it consumed is preserved because
     // the next serial is the high-water mark of numbers actually sent, not a
     // QSO count -- the X-QSO record stays in the log so it still counts toward
     // that mark.  See NextSerialToSend / MaxSerialSent, Issue #954.)
     SendDeletedContactToUDP(EditableQSORXData);
     HamScoreOnDelete(EditableQSORXData);
     end
  else
     begin
     LogEditedContactToUDP(EditableQSORxData);
     if Assigned(externalLogger) then
        begin
        // Issue #957 -- an edit is a delete of the original record followed by a
        // re-log of the edited one.  ReplaceQSO queues this as ONE atomic operation
        // delivered off the main thread: the delete and re-log go on separate
        // connections (DXKeeper reads one command per connection), and the re-log is
        // sent only if the delete succeeds.  Non-blocking -- no UI freeze.
        externalLogger.ReplaceQSO(EditableQSORXData);
        end;
     // Issue #783 -- HamScore RTC: send <contactreplace> next cycle.
     HamScoreOnEdit(EditableQSORxData);
     end;

  if not OpenLogFile then
     begin
     Exit;
     end;

  tSetFilePointer(IndexInMap, FILE_BEGIN);

  EditableQSORXData.ceNeedSendToServerAE := True;
  SendRecordToServer(NET_EDITEDQSO_ID, EditableQSORXData);

  sWriteFile(LogHandle, EditableQSORXData, SizeOf(ContestExchange));
  CloseLogFile;
  if FullLogEditHandle <> 0 then
     begin
     ListView_DeleteItem(LogEditListView, FullLogEditIndex);
     tAddContestExchangeToLog(EditableQSORXData, LogEditListView,
       FullLogEditIndex);
     ListView_SetItemState(LogEditListView, FullLogEditIndex - 1, LVIS_FOCUSED or
       LVIS_SELECTED, LVIS_FOCUSED or LVIS_SELECTED);
     end;

  tUpdateLog(actRescore);
  LoadinLog;
  if FindStationInCallsignColumn(EditableQSORXData.Callsign) = -1 then
     begin
     AddCallsignToStationColumn(EditableQSORXData.Callsign);
     end;
  UpdateAllStationsList;
  So2R_Swap := False;
 end;

function CheckSystemTimeRecord(Time: TQSOTime): boolean;
begin
  Result := True;
  if not (Time.qtYear in [0..255]) then
     begin
     Result := False;
     end;
  if not (Time.qtMonth in [1..12]) then
     begin
     Result := False;
     end;
  if not (Time.qtDay in [1..31]) then
     begin
     Result := False;
     end;
  if not (Time.qtHour in [0..23]) then
     begin
     Result := False;
     end;
  if not (Time.qtMinute in [0..59]) then
     begin
     Result := False;
     end;
  if not (Time.qtSecond in [0..59]) then
     begin
     Result := False;
     end;
  if Result = False then
     begin
     showwarning(TC_CHECKDATETIME);
     end;
end;

procedure ShowNote(CE: ContestExchange);
begin
  TF.Format(wsprintfBuffer, PAnsiChar(WinAnsi(RC_NOTE + ' :'#13#10#13#10'%s')),
    @EditableQSORXData.Prefix);
  ShowMessageParent(wsprintfBuffer, EditQSOFormHandle);
end;

procedure OpenEditQSOWindow(Parent: HWND);
begin
   // ICC_DATE_CLASSES went with the template. It registered the common
   // control class behind SysDateTimePick32 so DialogBox could create one
   // from the resource; a TDateTimePicker brings its own.
   uEditQSOForm.ShowEditQSO(Parent);
end;

end.


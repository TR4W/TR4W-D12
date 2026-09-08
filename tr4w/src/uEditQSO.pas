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
  uStations,
  WinSock2,
  uNet,
  TF,
  VC,
  //Country9,
  LCLType,
  DateUtils,   // TryEncodeDateTime / DecodeDateTime -- replace SYSTEMTIME
  uCallSignRoutines,
  utils_file,
  LogCW,
  uTotal,
  Tree,
  LOGSUBS1,
  LOGSUBS2,
  LogDupe,
  LogStuff,
  ZoneCont,
  LogK1EA,
  LogEdit,
  LogWind,
(* Messages: named, and used nowhere in this unit (2026-09-08). *)
  uTR4WStrings,
  uAnsiStr;

procedure OpenEditQSOWindow;

// THE FOUR HALVES THE LCL FORM CALLS BACK INTO (Phase 5, 2026-08-19).
// The behaviour stayed in this unit -- it owns the log record and the
// ContestExchange it is editing -- and src\ui\lcl\uEditQSOForm.pas is
// presentation plus the id-to-control shim. That split is why the save
// function below still reads field by field, by the SAME control ids.
function  LoadQSOIntoEditForm: boolean;
procedure CallsignChangedInEditForm;
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
  (* FLD_PLAY_BUTTON (201) went with the MP3 play button, 2026-09-07. *)

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
  { The SQLite shadow -- an IMPLEMENTATION-section use, so no interface
    cycle. It never raises and never blocks logging: see uLogStore. }
  uLogStore,
  (* Which store a log READ comes from -- step B4/B5. *)
  uLogSource,
   uPlatformProcess,   // RunProgram / RunWindowsUtility -- the only launchers
  SysUtils,         // SystemTimeToDateTime / DateTimeToSystemTime
  MainUnit,
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
  qsoWhen: TDateTime;
begin
   Result := False;

   IndexInMap := IndexOfItemInLogForEdit;

   (* A RECORD INDEX NOW, not a byte offset -- see VC.IndexOfItemInLogForEdit.
      Read through the seam, so this reads whichever store the program reads. *)
   if not LogSourceOpen then
      begin
      Exit;
      end;

   if not LogSourceReadAtIndex(IndexInMap, EditableQSORXData) then
      begin
      LogSourceClose;
      Exit;
      end;
   LogSourceClose;

   if EditableQSORXData.ceRecordKind = rkNote then
      begin
      ShowNote(EditableQSORXData);
      Exit;
      end;

   (* THE PLAY BUTTON IS GONE (2026-09-07), with the recorder that made the
     files it played. MakeMP3Filename built a path under Config.MP3Path from the
     QSO's call, band and time -- a naming convention that belonged to TR4W's own
     recorder and describes nothing an external recorder writes. NY4I chose to
     remove playback rather than keep it pointing at a directory nothing fills.

     EditableQSORXData.MP3Record is still read from the log; it simply has no
     button to enable. *)

   if (EditableQSORXData.ceQSO_Deleted) or
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
   (* DateUtils, NOT a Win32 SYSTEMTIME. The record existed only to be handed
     to SystemTimeToDateTime -- so the whole detour is one EncodeDateTime, and
     SYSTEMTIME was the only thing left in this unit needing the Windows unit.

     TryEncodeDateTime RATHER THAN EncodeDateTime, and that is a fix rather
     than a translation: a log record with a zeroed or damaged date -- month 0,
     day 0 -- used to be handed to SystemTimeToDateTime, which is documented as
     undefined for input it would not itself have produced. EncodeDateTime
     raises EConvertError on the same input, which in a dialog that OPENS on a
     QSO would be an exception instead of a date field. Try* reports it, and
     the QSO still opens showing the epoch. *)
   if not TryEncodeDateTime(EditableQSORXData.tSysTime.qtYear + 2000,
                            EditableQSORXData.tSysTime.qtMonth,
                            EditableQSORXData.tSysTime.qtDay,
                            EditableQSORXData.tSysTime.qtHour,
                            EditableQSORXData.tSysTime.qtMinute,
                            EditableQSORXData.tSysTime.qtSecond,
                            0, qsoWhen) then
      begin
      qsoWhen := 0;
      if logger <> nil then
         begin
         logger.Warn('[EditQSO] QSO has an unusable date (%d-%d-%d %d:%d:%d) ' +
                     '-- showing the epoch instead',
                     [EditableQSORXData.tSysTime.qtYear + 2000,
                      EditableQSORXData.tSysTime.qtMonth,
                      EditableQSORXData.tSysTime.qtDay,
                      EditableQSORXData.tSysTime.qtHour,
                      EditableQSORXData.tSysTime.qtMinute,
                      EditableQSORXData.tSysTime.qtSecond]);
         end;
      end;
   EditQSOSetDateTime(qsoWhen);

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

   FillChar(EditableQSORXData.QTH, SizeOf(EditableQSORXData.QTH), 0);
   ctyLocateCall(TempString, EditableQSORXData.QTH);

   if DoingPrefixMults then
      begin
      FillChar(EditableQSORXData.Prefix, SizeOf(EditableQSORXData.Prefix), 0);
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
  qsoY, qsoMo, qsoD, qsoH, qsoMi, qsoS, qsoMs: word;
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

  (* DecodeDateTime, not DateTimeToSystemTime -- see the note in the reader
    above. The guard on the year is unchanged: a date before 2000 leaves
    qtYear alone rather than storing a negative, because qtYear is a byte
    holding years-since-2000. *)
  DecodeDateTime(EditQSOGetDateTime, qsoY, qsoMo, qsoD, qsoH, qsoMi, qsoS, qsoMs);

  if qsoY >= 2000 then
     begin
     EditableQSORXData.tSysTime.qtYear := qsoY - 2000;
     end;
  EditableQSORXData.tSysTime.qtMonth := qsoMo;
  EditableQSORXData.tSysTime.qtDay := qsoD;
  //Time
  EditableQSORXData.tSysTime.qtSecond := qsoS;
  EditableQSORXData.tSysTime.qtMinute := qsoMi;
  EditableQSORXData.tSysTime.qtHour := qsoH;


    {Callsign}
  //  EditableQSORXData.Callsign := GetDialogItemText(eq_handle, 118);
  FillChar(EditableQSORXData.Callsign, SizeOf(CallString), 0);
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
     FillChar(EditableQSORXData.DXQTH, SizeOf(EditableQSORXData.DXQTH), 0);
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
  FillChar(EditableQSORXData.Frequency, SizeOf(EditableQSORXData.Frequency), 0);
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
     FillChar(EditableQSORXData.Age, SizeOf(EditableQSORXData.Age), 0);
     EditableQSORXData.Age := lpNumberOfBytesWritten;
     end;

  {Chapter}
  FillChar(EditableQSORXData.Chapter, SizeOf(EditableQSORXData.Chapter), 0);
  EditableQSORXData.Chapter := EditQSOGetText(FLD_CHAPTER);
  {Check}
  FillChar(EditableQSORXData.Check, SizeOf(EditableQSORXData.Check), 0);
  EditableQSORXData.Check := EditQSOGetInt(FLD_CHECK, lpTranslated);
  {ClassCE}
  FillChar(EditableQSORXData.ceClass, SizeOf(EditableQSORXData.ceClass), 0);
  EditableQSORXData.ceClass := EditQSOGetText(FLD_CLASS);

  {NumberSent}
  FillChar(EditableQSORXData.NumberSent, SizeOf(EditableQSORXData.NumberSent), 0);
  EditableQSORXData.NumberSent := EditQSOGetInt(FLD_NUMBERSEND, lpTranslated);

  {NumberReceived}
  TempInteger := EditQSOGetInt(FLD_NUMBERRECEIVED, lpTranslated);
  if lpTranslated then
     begin
     FillChar(EditableQSORXData.NumberReceived, SizeOf(EditableQSORXData.NumberReceived), 0);
     EditableQSORXData.NumberReceived := TempInteger;
     end;

  {DomMultQTH}
//  EditableQSORXData.DomMultQTH := GetDialogItemText(eq_handle, FLD_DOMMULTQTH);
//  EditableQSORXData.DomMultQTH[0] := AnsiChar(Windows.GetDlgItemTextA(eq_handle, FLD_DOMMULTQTH, @EditableQSORXData.DomMultQTH[1], SizeOf(EditableQSORXData.DomMultQTH) - 1));

  {Prefix}
  FillChar(EditableQSORXData.Prefix, SizeOf(EditableQSORXData.Prefix), 0);
  EditableQSORXData.Prefix := EditQSOGetText(FLD_PREFIX);

  {Zone}

  TempByte := Byte(EditQSOGetInt(FLD_ZONE, lpTranslated));
  if lpTranslated then
     begin
     FillChar(EditableQSORXData.Zone, SizeOf(EditableQSORXData.Zone), 0);
     EditableQSORXData.Zone := TempByte
     end
  else
     begin
     if TempByte = 0 then
        begin
        FillChar(EditableQSORXData.Zone, SizeOf(EditableQSORXData.Zone), 0);
        EditableQSORXData.Zone := DUMMYZONE;
        end;
     end;

  {Name}
  FillChar(EditableQSORXData.Name, SizeOf(EditableQSORXData.Name), 0);
  EditableQSORXData.Name := EditQSOGetText(FLD_NAME);

  {QTHString}
  // The next line was commented out - so test this well ny4i Issue112
  FillChar(EditableQSORXData.QTHString, SizeOf(EditableQSORXData.QTHString), 0);
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
  FillChar(EditableQSORXData.Power, SizeOf(EditableQSORXData.Power), 0);
  EditableQSORXData.Power :=
    EditQSOGetText(FLD_POWER);

  {Precedence}
  TempString := EditQSOGetText(FLD_PRECEDENCE);
  FillChar(EditableQSORXData.Precedence, SizeOf(EditableQSORXData.Precedence), 0);
  if TempString <> '' then
     begin
     EditableQSORXData.Precedence := AnsiChar(TempString[1]);
     end;

  {Prefecture}
  TempByte := Byte(EditQSOGetInt(FLD_PREFECTURE, lpTranslated));
  if lpTranslated then
     begin
     FillChar(EditableQSORXData.Prefecture, SizeOf(EditableQSORXData.Prefecture), 0);
     EditableQSORXData.Prefecture := TempByte;
     end;

  {TenTenNum}
  TempWord := Word(EditQSOGetInt(FLD_TENTENNUM, lpTranslated));
  if lpTranslated then
     begin
     FillChar(EditableQSORXData.TenTenNum, SizeOf(EditableQSORXData.TenTenNum), 0);
     EditableQSORXData.TenTenNum := TempWord;
     end;

  {RSTSent}
  TempInteger := EditQSOGetInt(FLD_RSTSEND, lpTranslated);
  if lpTranslated then
     begin
     FillChar(EditableQSORXData.RSTSent, SizeOf(EditableQSORXData.RSTSent), 0);
     EditableQSORXData.RSTSent := TempInteger {TempWord};
     end;

  {RSTReceived}
  TempInteger := EditQSOGetInt(FLD_RSTRECEIVED, lpTranslated);
  if lpTranslated then
     begin
     FillChar(EditableQSORXData.RSTReceived, SizeOf(EditableQSORXData.RSTReceived), 0);
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
  (* AnsiString: ceOperator is written to the binary log and exported, and
    every other text field of the record is assigned the same way. WinAnsi
    would have given this one field a different encoding from its
    neighbours in the same record. *)
  ansiOperator := AnsiString(EditQSOGetText(FLD_OPERATOR));
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

  (* THE `if not OpenLogFile then Exit` THAT STOOD HERE DISCARDED EVERY EDIT.

    OpenLogFile is CreateFileA(TR4W_LOG_FILENAME, ..., OPEN_EXISTING) -- it
    opens the BINARY .TRW. This build does not create one, so on any contest
    started under it the call returned False and this routine RETURNED, before
    SendRecordToServer and before LogStoreUpdateQSOAtIndex. Nothing was written
    and nothing was said: the dialog closed as though it had saved.

    FOUND FROM A BENCH REPORT, not from a test (NY4I, 2026-09-02): X-QSO would
    not stick. It was never about X-QSO -- no field of any edited QSO was ever
    saved, and X-QSO is simply the one he tried. The directory listing is what
    gave it away: a .db, a -wal, a -shm and NO .TRW.

    IT WAS A GATE ON A FILE THIS ROUTINE NO LONGER USES. The seek-and-write it
    once guarded was removed when the store moved (see the note below); the
    guard outlived the code it guarded, which is the failure mode of a check
    kept "just in case" after its subject is gone.

    AND IT LEAKED. On a station that still HAD a .TRW the call succeeded, set
    the global LogHandle, and nothing here ever closed it -- a handle per edit.

    THE LogSourceClose THAT FOLLOWED IT IS GONE TOO. It closed a source this
    routine never opened: LoadQSOIntoEditForm opens and closes its own around
    the read (uEditQSO.pas:169-179), so this was unbalanced in the other
    direction. LogStoreUpdateQSOAtIndex opens what it needs. *)

  EditableQSORXData.ceNeedSendToServerAE := True;
  SendRecordToServer(NET_EDITEDQSO_ID, EditableQSORXData);

  (* NO DIVISION ANY MORE, AND THAT DIVISION WAS A BUG.

     This read `IndexInMap div SizeOf(ContestExchange)` to turn a byte offset
     back into a record position. SizeOfTLogHeader and SizeOf(ContestExchange)
     are BOTH 376 bytes, so the offset of record k is (k + 1) * 376 and the
     division returned k + 1: every edit updated the row AFTER the one the
     operator was editing. Both stores held a QSO the operator never touched,
     and the one they did edit kept its old values.

     IndexInMap is the record index itself now, so there is nothing to
     convert. *)
  LogStoreUpdateQSOAtIndex(IndexInMap, EditableQSORXData);
  (* THE LOG EDIT WINDOW REFRESHES ITSELF NOW.

    This deleted a row out of the old Win32 dialog's listview and re-inserted
    it, because that list held the rows and nothing else could have known the
    QSO had changed. uLogEditForm is a VIRTUAL list: it holds no rows, so it
    re-reads the record the next time it paints, and it invalidates itself
    after the editor closes. Nothing here needs to know it exists.

    The three globals this used -- FullLogEditHandle, LogEditListView,
    FullLogEditIndex -- went with the dialog. *)

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
  TF.Format(wsprintfBuffer, PAnsiChar(LclText(RC_NOTE + ' :'#13#10#13#10'%s')),
    @EditableQSORXData.Prefix);
  ShowMessage(string(wsprintfBuffer));
end;

procedure OpenEditQSOWindow;
begin
   // ICC_DATE_CLASSES went with the template. It registered the common
   // control class behind SysDateTimePick32 so DialogBox could create one
   // from the resource; a TDateTimePicker brings its own.
   uEditQSOForm.ShowEditQSO;
end;

end.


{ Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit TF;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses

  VC,
  utils_text,
(* WINDOWS IS GATED NOW, AND THAT IS WHAT MAKES THE GATE ON CreateRichEdit
    REAL. A unit whose CODE is behind {$IFDEF WINDOWS} but whose USES clause is
    not can never compile anywhere else -- the compiler fails on the clause and
    never reaches the code. NY4I: "do you also need to put ifdef windows around
    the windows uses declaration?" Yes, and without it the rest is decoration.

    What is still behind it: CreateRichEdit, which builds the RICHED32 control
    that MMTTY -- a separate Windows program -- writes into. LCLType carries
    the types (HWND, MAXWORD) for every widget set. *)
{$IFDEF WINDOWS}
  Windows,
{$ENDIF}
  LCLType,
  Classes,      // TFileStream -- EnumerateLinesInFile reads rather than maps
  DateUtils,    // EncodeDateTime / DecodeDateTime / LocalTimeToUniversal
  SysUtils,
  Messages,
  uTR4WStrings;

type
  MYDLGTEMPLATE = packed record
   {04}Style: DWORD;
   {04}dwExtendedStyle: DWORD;
   {02}cdit: Word;
   {02}X: SHORT;
   {02}Y: SHORT;
   {02}cx: SHORT;
   {02}cy: SHORT;
{18}
{04}d: Word;
{
b:byte;
b2:byte;
bbb: array[0..5] of Byte;
c80: array[0..3] of Byte;
    fn: array[0..170] of AnsiChar;
  }end;

  TEnumLinesFunc = procedure(Line: PShortString);

const
  LB_STYLE_1                            = LBS_NOTIFY or LBS_OWNERDRAWFIXED or LBS_NOINTEGRALHEIGHT or LBS_MULTICOLUMN or WS_CHILD or WS_VISIBLE or WS_VSCROLL or WS_HSCROLL or WS_TABSTOP;
  LB_STYLE_2                            = LBS_NOTIFY or LBS_OWNERDRAWFIXED or LBS_HASSTRINGS or LBS_NOINTEGRALHEIGHT or LBS_MULTICOLUMN or WS_CHILD or WS_VISIBLE or WS_VSCROLL or WS_HSCROLL or WS_TABSTOP;
  LB_STYLE_3                            = LBS_NOTIFY or LBS_MULTIPLESEL or LBS_HASSTRINGS or LBS_NOINTEGRALHEIGHT or WS_CHILD or WS_VISIBLE or WS_VSCROLL or WS_TABSTOP;

  Ten                                   : Double = 10.0;
  Layout                                : array[0..9] of AnsiChar = ('0', '0', '0', '0', '0', '4', '0', '9', #0, #0);
  UNKNOWNTYPE                           = 255;
const
  LISTVIEW                              = 'SysListView32';
  ES_SAVESEL                            = $00008000;
var
//  StrCompCOUNT                     : integer;
  tempDLGTEMPLATE                       : MYDLGTEMPLATE;
  Shell32LibHandle                      : DWORD;
  ButtonPChar                           : PChar = 'Button';
  StaticPChar                           : PChar = 'STATIC';
  COMBOBOX                              : PChar = 'COMBOBOX';
  EditPChar                             : PChar = 'Edit';
  LISTBOX                               : PChar = 'LISTBOX';

  wsprintfBuffer                        : array[0..4096 - 1] of AnsiChar;
  tempprintfBuffer                      : array[0..4096 - 1] of AnsiChar;   // To use with wsPrintfBuffer Issue 601 ny4i
  MillisecondsBuffer                    : array[0..31] of AnsiChar;
  QuickDisplayBuffer                    : array[0..255] of AnsiChar;
  TempBuffer1                           : array[0..255] of AnsiChar;
  TempBuffer2                           : array[0..255] of AnsiChar;
  SetDlgItemTextBuffer                  : array[0..255] of AnsiChar;
  // TelnetBuffer (20 KB, array[0..4096*5-1] of AnsiChar) is GONE.  It was the
  // DX cluster's shared receive buffer: the socket wrote into it, the line
  // scanner chopped it up in place, and the spot decoder read it by fixed
  // offset -- which is why the decoder could not run anywhere the global was
  // not live.  The transport now delivers whole lines and the decoder takes
  // one as a parameter (uDXClusterClient / uTelnet.ProcessDX).
  spotsBuffer                            : array[0..4096 * 5 - 1] of AnsiChar;
  NetBuffer                             : array[1..4096] of AnsiChar;
  SyncNetBuffer                         : array[0..4096 - 1] of AnsiChar;
  SYSERRORBUFFER                        : array[0..255] of AnsiChar;

  GETREALPATHBUFFER                     : array[0..255] of AnsiChar;

  LogDisplayBuffer                      : array[0..128 - 1] of AnsiChar;
  IntToPCharBuffer                      : array[0..15] of AnsiChar;
  FreqToPCharBuffer                     : array[0..15] of AnsiChar;

  GetDateFormatBuffer                   : array[0..31] of AnsiChar;

  GetTimeStringBuffer                   : array[0..31] of AnsiChar;
  SystemTimeToStringBuffer              : array[0..31] of AnsiChar;
  GetFullTimeStringBuffer               : array[0..31] of AnsiChar;
  GetYearStringBuffer                   : array[0..7] of AnsiChar;
  GetDateStringBuffer                   : array[0..15] of AnsiChar;
  IQPrompt                              : array[0..63] of AnsiChar;

{$IFDEF WINDOWS}
(* WINDOWS ONLY, DECLARATION AND ALL.  Its one caller is the MMTTY window, and
  MMTTY is a separate Windows EXE showing its output in a RICHED32 control --
  there is nothing to create anywhere else.  Gating the DECLARATION rather than
  just the body is what lets TF stop naming HWND. *)
function CreateRichEdit(hwndParent: HWND): HWND;
{$ENDIF}

function EnumerateLinesInFile(FileName: PAnsiChar; Func: TEnumLinesFunc; UpperCase: boolean): boolean;
function tGetDateFormat(DT: TQSOTime): PAnsiChar; //assembler;
procedure UnableToFindFileMessage(FileName: string);
function DeleteSlashes(p: PAnsiChar): PAnsiChar;
function SetParameterInArray(ArrayPtr: PInteger; ArrayLength: integer; aVar: PInteger; ValueToSet: integer): boolean;
function GetGUID: string;
function GetValueFromArray(PCharArrayAddress: PAnsiChar; ArraySize: Byte; const CMD: AnsiString): Byte;
function GetNumberFromCharBuffer(p: PAnsiChar): integer;
procedure tLoadKeyboardLayout;
function GetContestFromString(ContestString: ShortString): ContestType;
function STToInt64(St: SYSTEMTIME): int64;
function RealToStr2(Num: REAL): string;
function PCharToInt(p: PAnsiChar): integer;
function BooleanToStr(b: boolean): string;
//function CenterString(s: string; count: byte): string;
procedure strU(var Str: OpenString);
function IntegerBetween(v: integer; i: integer; k: integer): boolean;

// ValExt removed -- see the note at its old implementation site.  Callers use
// the RTL `Val` intrinsic, which is what uCTYDAT already does.

type
   (* FPC's Windows unit declares TFNThreadStartRoutine as a bare Pointer, so
     this is the same type under a name TF owns -- see tCreateThread. *)
   TTR4WThreadStart = Pointer;

{ START A WORKER THREAD WHOSE FAULTS ARE NOT SILENT, AND WHOSE ALLOCATIONS ARE
  NOT A RACE.  Two defects, both measured on 2026-08-23, both fixed by routing
  through the RTL instead of calling CreateThread directly.  See the body. }
(* TTR4WThreadStart, not Windows' TFNThreadStartRoutine.

  FPC declares that as a bare Pointer -- see the note in the body -- so this is
  the same type under a name TF owns, and every one of the seventeen call sites
  passes @SomeProc, which is Pointer-compatible either way. It was the only
  reason this declaration needed the Windows unit. *)
function tCreateThread(lpStartAddress: TTR4WThreadStart; var lpThreadId: DWORD; Quiet: boolean = False; aParameter: Pointer = nil): THandle;

//function tgethostbyname(h_Name: PAnsiChar): PAnsiChar;
(* tDialogBox IS DELETED (2026-08-31).  Its last live caller went with the
   Cabrillo summary dialog; the one that LOOKS like a caller, in MainUnit's
   SelectFileOfFolder, has been inside a brace comment for years.  It also held
   the only remaining reference to the CreateCabrilloWindow global, which is
   why both go in the same commit. *)
(* tWM_SETFONT IS GONE.  It wrapped one SendMessage and had exactly one caller
  -- CreateRichEdit, three lines below its own body -- so it was a name for a
  line rather than an abstraction, and it cost TF two more HWNDs in its
  interface.  The send is now written where it happens. *)

function SystemTimeToString(SysTime: SYSTEMTIME): string;

//function StrLen(const Str: PChar): Cardinal;
{ tWindowsExist MOVED to uWindowTable -- it reads the window table, and TF is
  in tr4wserver's unit graph. }


procedure showwarning(Text: string);
procedure ShowSysErrorMessage(ID: PAnsiChar);


//function tr4w_GetTimeString: PChar;
function RITFreqToPchar(i: integer): string;
function FreqToPChar(i: integer): string;
function FreqToPChar2(i: integer): string;
function FreqToPCharWithoutHZ(i: integer): string;
//function InitSysMonthCal32: boolean;
function MillisecondsToFormattedString(msecs: Cardinal; WithMsec: boolean): string;

//function Pos(Substr: string; S: string): Integer;
procedure InvertBoolean(var b: boolean);
function inttopchar(i: integer): PAnsiChar;
(* DragWindow IS GONE (2026-09-07). It posted WM_SYSCOMMAND / SC_MOVE to hand
  a drag to the system's own move loop -- a Win32 idiom carried over from the
  original program, and not how an LCL application moves a window.

  Its one caller, TTR4WMainForm.MainFormMouseDown, does the drag itself now
  with OnMouseDown/Move/Up. That is portable, it can be driven by a test, and
  it shares the edge-snap rule with the caption drag (uWindowSnap). *)
//procedure SaveStructure(Address: Pointer; Count: integer; FileName: string);
//function tShellexecute(HWND: HWND; Operation, FileName, Parameters, Directory: PChar; showCmd: integer): hInst; // 4.75.3

function tOpenFileForRead(var h: THandle; FileName: PAnsiChar): boolean;

procedure GetTime(var Hour, Minute, Second, Sec100: Word);
procedure GetDate(var Year, Month, Day, DayOfWeek: Word);

{$EXTERNALSYM Format}
{ THESE ARE cdecl wsprintf WRAPPERS, and every parameter is 8-bit.

  So a caller passing a TC_/RC_ constant as the format string has to write
  PAnsiChar(WinAnsi(TC_WHATEVER)) since 2026-08-27, when those constants
  became resourcestrings. There are 38 such call sites and the cast is on the
  FORMAT STRING only -- the buffers being written are AnsiChar arrays, so the
  whole path is 8-bit and the conversion changes nothing that was not already
  8-bit. It does mean a non-Latin format string is degraded here, which is a
  real limit of the Win32 display path and goes away with it.

  Prefer SysUtils.Format in new code: it takes a string, takes its arguments
  as an array of const rather than by cdecl varargs, and cannot be handed the
  wrong argument type without the compiler noticing. }
function Format(Output: PAnsiChar; Format: PAnsiChar; c: AnsiChar): integer; overload; cdecl; overload;

function Format(Output: PAnsiChar; Format: PAnsiChar; s1: PAnsiChar; u1: integer; u2: integer; u3: integer; u4: integer; u5: integer; u6: integer; s2: PAnsiChar; s3: PAnsiChar): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; p4: PAnsiChar): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; p4: PAnsiChar; p5: PAnsiChar): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; i: integer): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; i: integer; i2: integer): integer; overload; cdecl; overload;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; i: integer): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar): integer; overload; cdecl; overload;

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer; i3: integer): integer; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer; p: PAnsiChar): integer; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer): integer; overload; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer): integer; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; p: PAnsiChar): integer; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer): integer; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer; i2: integer): integer; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer; P2: PAnsiChar): integer; cdecl; overload;
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; p: PAnsiChar; i2: integer): integer; cdecl; overload;

function Format(Output: PAnsiChar; Format: PAnsiChar; P1, P2, p3, p4, p5, p6, p7: PAnsiChar): integer; cdecl; overload;
//function pos(Substr: string; s: string): integer;
const
  shell32                               = 'shell32.dll';
  { $ E X TERNALSYM Shell Execute}
  //function Shellexecute(HWND: HWND; Operation, FileName, Parameters, Directory: PChar; showCmd: integer): hInst; stdcall;
  { $ E X TERNALSYM Extract IconEx }
  //function ExtractIconEx(lpszFile: PChar; nIconIndex: integer; var phiconLarge, phiconSmall: HICON; nIcons: UINT): UINT; stdcall;

implementation

uses Log4D, uFreqTimeFormat, uStrSearch, uAnsiStr, uCFormat,   // Issue #997: freq/time formatters + PChar search helpers extracted + golden-tested
     uCrashLog,   // LogCaughtException, OnMainThread, ReportOffMainThread
     (* THE LCL'S DIALOGS, for showwarning, and uMainThread to get onto the
       main thread first. This does not undo the weight this unit is careful
       about: what it avoids is MainUnit and the radio factory behind it, not
       the LCL, which all three programs -- the app, tr4wserver and the unit
       tests -- link already. *)
     Dialogs,
     uMainThread;

// Own Log4D logger (initialized at the foot of this unit), replacing the former
// MainUnit.logger borrow.  MainUnit was used for NOTHING ELSE here -- three
// logger calls were the whole dependency -- and it is the heaviest edge in the
// program: TF -> MainUnit -> LOGRADIO -> uFactoryRadioBase -> the entire radio
// factory.  Anything wanting TF's formatting helpers had to link all of that.
//
// Same treatment, and the same reason, as uMults (Issue #1034).  It is what
// lets TR4WServer -- which needs exactly three TF routines (STToInt64,
// ShowSysErrorMessage, tOpenFileForRead) and no radio code whatsoever -- build
// as a standalone D12 EXE.
//
// Log4D hands back a logger for the category, wired to the same appenders, so
// these lines still land in tr4w.log; they now carry their own category name
// instead of the generic one, exactly as the radio drivers do.
var
  logger: TLogLogger;























//uses mainunit;

// SysErrorMessage removed (D12): use SysUtils.SysErrorMessage (returns a
// trimmed string). TF's version was a duplicate that returned PAnsiChar into a
// static buffer, untrimmed; the trailing-CRLF difference is cosmetic.

(* Shows the warning once we are known to be on the main thread. Called
  directly, or through uMainThread when showwarning was reached from a worker.
  aData is a PString this routine owns and disposes. *)
type
  (* ^string, NOT PString. FPC declares PString as ^AnsiString under {$H+},
    so carrying our UTF-16 text through one would narrow it on the way in and
    widen it again on the way out -- a round trip through the system code page
    for no reason, in the one path that exists to report a problem. *)
  PWarningText = ^string;

procedure ShowWarningOnMainThread(aData: PtrInt);
var
  text: PWarningText;
begin
  text := PWarningText(aData);
  try
     MessageDlg('TR4W', LclText(text^), mtWarning, [mbOK], 0);
  finally
     Dispose(text);
  end;
end;

procedure showwarning(Text: string);
var
  carried: PWarningText;
begin
  logger.Warn(Text);

  // Silent/batch export (/EXPORT) runs headless with no operator to dismiss a
  // modal -- a MessageBox would block the run indefinitely (e.g. the ARRL10 /
  // Winter Field Day "LOCATION field is empty" check in PostUnit). The warning
  // is already in the log above; skip the modal in that mode.
  if tSilentExport then Exit;

  (* THE THREAD GUARD LIVES HERE, not at the call sites, because at least one
    caller is not on the main thread: uRadioIcomBase warns about CI-V Transceive
    being off from inside the CI-V parser, which runs on TReadingThread.

    MessageBoxW did not care -- Win32 will put up a message box from any thread,
    on that thread's own modal loop. An LCL MessageDlg is not safe that way, so
    swapping one for the other at the call site would have turned a working
    warning into an intermittent fault in a driver. Marshalling in the one place
    every warning already passes through makes every caller safe, including the
    ones nobody has audited.

    MB_SYSTEMMODAL and MB_TOPMOST are gone with the Win32 call. They existed to
    beat TR4W's always-on-top main window; an application-modal LCL dialog does
    not need them -- the same reasoning YesOrNo recorded when it converted. *)
  if OnMainThread then
     begin
     MessageDlg('TR4W', LclText(Text), mtWarning, [mbOK], 0);
     Exit;
     end;

  New(carried);
  carried^ := Text;
  RunOnMainThread(@ShowWarningOnMainThread, PtrInt(carried));
end;

function FreqToPChar2(i: integer): string;
begin
  // D12: returns native string; same %u.%u digits the wsprintf path produced.
  Result := SysUtils.Format('%u.%u', [i div 1000, (i mod 1000) div 100]);
end;

function RITFreqToPchar(i: integer): string;
var absI: integer;
begin  // This does not handle negative numbers very well.
   // D12: returns native string; format specs unchanged (%2u space-pad width 2)
   // so the display is byte-identical to the wsprintf path, quirk and all.
   // %.2u zero-pads the hundredths (min 2 digits) so 2060 -> "2.06" and -1080 ->
   // "-1.08". The old %2u space-padded to width 2, so a leading-zero hundredths
   // digit rendered as a space ("2. 6", "-1. 8"); it only surfaced once positive
   // RIT started displaying. (190 -> "0.19" is unchanged.)
   if i < 0 then
      begin
      absI := i * -1;
      Result := SysUtils.Format('-%u.%.2u', [absI div 1000, (absI mod 1000) div 10]);
      end
   else
      begin
      Result := SysUtils.Format('%d.%.2u', [i div 1000, (abs(i) mod 1000) div 10]);
      end;
end;

function FreqToPChar(i: integer): string;
begin
  // Issue #997: extracted to uFreqTimeFormat (golden-master tested).
  Result := uFreqTimeFormat.FreqToPChar(i);
end;

function FreqToPCharWithoutHZ(i: integer): string;
begin
  Result := uFreqTimeFormat.FreqToPCharWithoutHZ(i);   // Issue #997: extracted
end;

{
}

function GetGUID: string;   // Returns 32-char lowercase hex, no dashes or braces
var
   MyGUID: TGUID;
begin
   Result := '';
   (* 0, not S_OK. SysUtils declares CreateGUID for every platform and it
     returns 0 on success -- S_OK is the same value, but the NAME comes from
     ActiveX, which was the last Windows-only unit in this clause and was
     imported for this one comparison. *)
   if CreateGUID(MyGUID) <> 0 then
      begin
      logger.Warn('Could not create GUID');
      Exit;
      end;
   Result := LowerCase(
      Format('%.8x%.4x%.4x%.2x%.2x%.2x%.2x%.2x%.2x%.2x%.2x',
         [MyGUID.D1, MyGUID.D2, MyGUID.D3,
          MyGUID.D4[0], MyGUID.D4[1], MyGUID.D4[2], MyGUID.D4[3],
          MyGUID.D4[4], MyGUID.D4[5], MyGUID.D4[6], MyGUID.D4[7]]));
   logger.Debug('GUID created %s', [Result]);
end;




function MillisecondsToFormattedString(msecs: Cardinal; WithMsec: boolean): string;
begin
  // Issue #997: extracted to uFreqTimeFormat (golden-master tested).
  Result := uFreqTimeFormat.MillisecondsToFormattedString(msecs, WithMsec);
  //  MessageBox(0, Result, '���������', MB_OK);

end;

procedure InvertBoolean(var b: boolean);
begin
  b := not b;
end;

function inttopchar(i: integer): PAnsiChar;
begin
  Format(IntToPCharBuffer, '%d', i);
  Result := IntToPCharBuffer;
end;


{------------------------------------------------------------------}
{  Function to convert int to string. (No sys utils = smaller EXE)  }
{------------------------------------------------------------------}
{
}

function RealToStr2(Num: REAL): string;
begin
  //procedure Str(X [: Width [: Decimals ]]; var S);
  Str(Num: 2: 2, Result);
end;

// IntToStr removed (D12): use SysUtils.IntToStr -- the custom ShortString
// version existed only to avoid linking SysUtils ("smaller EXE"), obsolete now.

function BooleanToStr(b: boolean): string;
begin
   Result := 'FALSE';
   if b then
      begin
      Result := 'TRUE';
      end;
end;

{  Function to convert string to int. (No sys utils = smaller EXE)  }
{------------------------------------------------------------------}

// StrToInt removed (D12): callers now use SysUtils.StrToIntDef(s, 0), which
// preserves the old lenient "invalid -> 0" behavior (TF's version ran Val and
// discarded the error code). SysUtils.StrToInt is NOT equivalent -- it raises.

function PCharToInt(p: PAnsiChar): integer;
label
  1, 2;
var
  i                                     : integer;
  Negative                              : boolean;
begin
  Result := 0;
  i := 0;
  Negative := False;

  if p[i] = '-' then
     begin
     i := 1;
     Negative := True;
     end;

  1:
  if p[i] in ['0'..'9'] then
     begin
     Result := Result * 10 + (Ord(p[i]) - 48)
     end
  else
     begin
     goto 2;
     end;
  inc(i);
  goto 1;
  2:
  if Negative then
     begin
     Result := Result * -1;
     end;
end;

{
}

{
}
{
}

{From System}

{
function Pos(Substr: string; S: string): Integer;
begin
   Result := Pos_JOH_IA32_6(Substr,s);
end;
}

//function Shellexecute; EXTERNAL shell32 Name 'ShellExecuteA';
//function ExtractIconEx; EXTERNAL shell32 Name 'ExtractIconExA';
{
}

function STToInt64(St: SYSTEMTIME): int64;
begin
  (* MILLISECONDS SINCE 1601-01-01, which is what the FILETIME this replaces
    counted -- SystemTimeToFileTime gives 100-nanosecond ticks from that epoch
    and the old code divided by 10,000.

    The epoch does not actually matter to the only caller: uSynTime computes
    NTP offsets as STToInt64(t2) - STToInt64(t1), so any consistent origin
    would do. It is kept anyway, because a function that returns "milliseconds
    since 1601" and one that returns "milliseconds since something" are not
    the same function, and TR4WServer links this too.

    A malformed SYSTEMTIME -- month 0 from a truncated packet -- used to make
    SystemTimeToFileTime fail and leave TEMPFILETIME uninitialised, so the
    result was whatever the stack held. It reports and returns 0 now. *)
  Result := 0;
  try
     Result := MilliSecondsBetween(EncodeDateTime(St.wYear, St.wMonth, St.wDay,
                                                  St.wHour, St.wMinute,
                                                  St.wSecond, St.wMilliseconds),
                                   EncodeDate(1601, 1, 1));
  except
     on E: EConvertError do
        begin
        if logger <> nil then
           begin
           logger.Warn('[STToInt64] unusable SYSTEMTIME %d-%d-%d %d:%d:%d',
                       [St.wYear, St.wMonth, St.wDay,
                        St.wHour, St.wMinute, St.wSecond]);
           end;
        end;
  end;
end;
{
function tgethostbyname(h_Name: PAnsiChar): PAnsiChar;
var
  myhostent                        : Phostent;
begin
  Result := nil;
  myhostent := WinSock2.gethostbyname(h_Name);
  if myhostent <> nil then Result := iNet_ntoa(PInAddr(myhostent^.h_addr_list^)^);
end;
}

function SystemTimeToString(SysTime: SYSTEMTIME): string;
begin
  // Issue #997: extracted to uFreqTimeFormat (golden-master tested).
  Result := uFreqTimeFormat.SystemTimeToString(SysTime);
end;

procedure tLoadKeyboardLayout;
begin
  // showint(loword(GetKeyboardLayout(0)));
  // 68748313 - $4190419-rus
  // 67699721 - $4090409-eng
  {
  Hello Dmitriy,

and thank you for considering adding the Scandinavian characters. The
value of GetKeyboardLayout = 1245108 .

> and please tell me value of 'GetKeyboardLayout = ' in caption of the
> main window in TR4W.

73 and Happy New Year!

Jari OH6BG
//  Showint(LoWord(1245108));//65460   - $FFB4
  }
//  if LoWord(GetKeyboardLayout(0)) = $0419 then
//     LoadKeyboardLayout('00000409', KLF_ACTIVATE);   // issue 178 force Latin
end;
function GetContestFromString(ContestString: ShortString): ContestType;
var
  TempContest                           : ContestType;
begin
  ContestString[Ord(ContestString[0]) + 1] := #0;
  for TempContest := Succ(DUMMYCONTEST) to High(ContestType) do
    (* StrComp, the RTL's, rather than Windows.lstrcmpA. Both compare
      NUL-terminated bytes and return 0 on equality; lstrcmpA additionally
      applies the user's LOCALE, which is wrong here -- these are contest
      identifiers, not display text, and a Turkish locale famously does not
      fold 'I' the way the rest of this comparison assumes. *)
    if StrComp(ContestTypeSA[TempContest], @ContestString[1]) = 0 then
       begin
       Result := TempContest;
       Exit;
       end;
  Result := DUMMYCONTEST;
end;

function GetNumberFromCharBuffer(p: PAnsiChar): integer;
label
  1;
var
  b                                     : Byte;
  i                                     : integer;
begin
  Result := 0;
  i := 0;
  1:
  if p[i] in ['0'..'9'] then
     begin
     b := Byte(p[i]) - $30;
     Result := b + (Result * 10);
     inc(i);
     goto 1;
     end;
end;
{
function StrLen(const Str: PChar): Cardinal; assembler;
asm
        CMP    EAX , 0
        JZ     @@1
        MOV    EDX,EDI
        MOV    EDI,EAX
        MOV    ECX,0FFFFFFFFH
        XOR    AL,AL
        REPNE  SCASB
        MOV    EAX,0FFFFFFFEH
        SUB    EAX,ECX
        MOV    EDI,EDX
@@1:
end;
}

// StrPos removed (D12): callers use uAnsiStr.StrPos directly -- the
// TF -> uStrSearch -> RTL forwarding was asm-eradication scaffolding, obsolete now.

function GetValueFromArray(PCharArrayAddress: PAnsiChar; ArraySize: Byte; const CMD: AnsiString): Byte;
var
  b                                     : Byte;
  p                                     : Pointer;
begin
  // CMD IS A STRING, and used to be a PAnsiChar that this function indexed as
  // if it were a ShortString: `CMD[Ord(CMD[0]) + 1] := #0` read a length byte
  // out of a pointer type that has none, and WROTE a terminator back into the
  // caller's buffer -- a side effect on an argument nothing declared as var.
  // Every caller held a ShortString and passed its address.  Taking the value
  // instead deletes the length-byte walk, the @CMD[1] offset, and the mutation.
  for b := 0 to ArraySize {- 1} do
     begin
     p := PCharArrayAddress + (b * 4);
     p := Pointer(p^);
 //    showmessage(p);
     // CASE-INSENSITIVE, and this is a FIX rather than a loosening.
     //
     // The config loader uppercases the whole line before it is split into key
     // and value (LogCfg.pas ~601, EnumerateLinesInFile with UpperCase = True),
     // while these tables hold the DISPLAY spelling.  Six of them are not all
     // upper -- 'All', 'Yes', 'No', 'Indonesian Districts', 'NC QSO Party' --
     // so a value that was written correctly came back as 'ALL' and matched
     // nothing.  That is the whole of the SINGLE BAND SCORE incident of
     // 2026-08-16: Preferences wrote `SINGLE BAND SCORE=All`, and every later
     // start reported "Invalid statement in config file".
     //
     // Widening cannot reject anything that used to be accepted.  Checked
     // across all 40 spelling arrays: folding case creates NO new ambiguity.
     // (QSOPointMethodArray does contain two identical 'ONY' entries, so its
     // second one is unreachable by name -- but that is true today and is not
     // made worse here.)
     if uAnsiStr.StrIComp(PAnsiChar(CMD), PAnsiChar(p)) = 0 then
        begin
        Result := b;
        Exit;
        end;
     end;
  Result := UNKNOWNTYPE;
end;

function SetParameterInArray(ArrayPtr: PInteger; ArrayLength: integer; aVar: PInteger; ValueToSet: integer): boolean;
var
  b                                     : integer;
begin
  Result := False;

  for b := 0 to ArrayLength do
     begin

     if PInteger(PAnsiChar(ArrayPtr) + (b * 4))^ = ValueToSet then
        begin
        aVar^ := ValueToSet;
        Result := True;
        Exit;
        end;
     end;
end;

function tGetDateFormat(DT: TQSOTime): PAnsiChar; //assembler;

 
begin
{ $ I F LANG <> 'E1212NG'}

  (* %.2d, not %02d: this goes through TF.Format, which used to be
    wsprintfA and zero-padded. The RTL reads a leading 0 as part of the
    WIDTH and pads with spaces, so a single-digit day would render as
    ' 7-' rather than '07-'. *)
  Format(GetDateFormatBuffer, '%.2d-%.2d-%.2d', dt.qtDay, DT.qtMonth, DT.qtYear);
{
  St.wYear := 2000 + DT.qtYear;
  St.wMonth := dt.qtMonth;
  St.wDay := dt.qtDay;
  Windows.GetDateFormat(LOCALE_SYSTEM_DEFAULT, 0, @St, @DateFormat[1], @GetDateFormatBuffer, SizeOf(GetDateFormatBuffer));
}
 { $ E LSE}
{
  St.wYear := 2000 + DT.qtYear;
  St.wMonth := dt.qtMonth;
  St.wDay := dt.qtDay;
  Windows.GetDateFormat(LOCALE_SYSTEM_DEFAULT, 0, @St, 'dd-MMM-yy', @GetDateFormatBuffer, SizeOf(GetDateFormatBuffer));
}
{ $ I FEND}
  Result := GetDateFormatBuffer;
end;

procedure UnableToFindFileMessage(FileName: string);
begin
  // SysUtils.SysErrorMessage returns a (trimmed) string directly -- no cast.
  // (TF's own SysErrorMessage shadows it here and returns PAnsiChar untrimmed.)
  showwarning(SysUtils.Format('%s'#13#13'%s', [SysUtils.SysErrorMessage(GetLastError), FileName]));
end;

function DeleteSlashes(p: PAnsiChar): PAnsiChar;
var
  TempInteger                           : integer;
begin
  Result := p;
  for TempInteger := 0 to 255 do
     begin
     if p[TempInteger] = '/' then
        begin
        p[TempInteger] := '_';
        end;
     if p[TempInteger] = #0 then Break;
     end;
end;

procedure ShowSysErrorMessage(ID: PAnsiChar);
begin
  showwarning(SysUtils.Format('%s: %s', [string(ID), SysUtils.SysErrorMessage(GetLastOSError)]));
end;

{ What the trampoline carries across.  Heap-allocated by tCreateThread and
  disposed by the trampoline itself, because the two run on different threads
  and the parent does not wait. }
type
   { TFNThreadStartRoutine is a bare Pointer in FPC's Windows unit, not a
     procedural type, so the shape has to be stated here to be callable. }
   TWorkerProc = function(aParameter: Pointer): DWORD; stdcall;

   PWorkerStart = ^TWorkerStart;
   TWorkerStart = record
      Proc: TWorkerProc;
      Parameter: Pointer;
      { The same address again, untyped.  Delphi mode CALLS a procedural
        variable when you name it, so Proc cannot also be read as a value --
        and the crash line wants the address to resolve symbolically. }
      Address: Pointer;
   end;

{ THE GUARD.  A plain TThreadFunc -- the RTL's own convention -- that adapts to
  the stdcall thread procedure TR4W has always used, and wraps it. }
function tWorkerThreadTrampoline(aStart: Pointer): PtrInt;
var
  start: TWorkerStart;
  rc: DWORD;
begin
  Result := 0;
  start := PWorkerStart(aStart)^;
  Dispose(PWorkerStart(aStart));
  try
     rc := start.Proc(start.Parameter);
     Result := PtrInt(rc);
  except
     on E: TObject do
        begin
        // The whole point.  Without this the process simply vanishes: see the
        // note in tCreateThread below.
        LogCaughtException(Format('worker thread %d (%s)',
                                  [GetCurrentThreadId,
                                   BackTraceStrFunc(CodePointer(start.Address))]), E);
        end;
  end;
end;

function tCreateThread(lpStartAddress: TTR4WThreadStart; var lpThreadId: DWORD; Quiet: boolean; aParameter: Pointer): THandle;
var
  start: PWorkerStart;
  id: TThreadID;
begin
  { BeginThread, NOT CreateThread, AND IT IS NOT A STYLE PREFERENCE.  Measured
    with a standalone FPC probe on 2026-08-23, because both of these had been
    argued from first principles and both first principles were wrong.

    1. IsMultiThread STAYS FALSE FOR A RAW CreateThread THREAD.  The probe
       spawned one, allocated a string on it, and IsMultiThread was still FALSE
       on return.  That flag is what makes the FPC heap manager take its locks,
       so until something else in the process happens to construct a TThread,
       TR4W's raw worker threads and the main thread were allocating from an
       UNLOCKED heap.  Sixteen TThread descendants exist (radio reading threads,
       the DX cluster reader, the uploaders), so in practice the flag does get
       set -- but by an unrelated object, at an unrelated moment, and nothing
       ordered that before the first raw thread.  BeginThread sets it in the
       PARENT before the child starts, which is the ordering we actually want.

    2. A FAULT ON A WORKER THREAD REACHED NO HANDLER AT ALL.
       Application.HandleException covers only the main message loop and
       ExceptProc covers the main thread, so an access violation on a radio
       reading thread ended the process with NOTHING in tr4w.log -- the last
       line being whatever that thread wrote just before.  That is not a
       hypothetical: it cost five of NY4I's test cycles on 2026-08-23 to find
       an LCL call being made from the radio polling thread, because the log
       kept pointing at the answer and it kept reading as coincidence.

       The probe also settled the question that made this look impossible:
       try/except DOES work on such a thread under FPC/win32 -- it caught both
       a raise and an access violation, with a valid ExceptAddr -- so the guard
       produces a real symbolic backtrace, not just "it died".

    The return value is the thread HANDLE, as before; lpThreadId gets the id,
    as before.  Callers see no change. }
  New(start);
  start^.Proc := TWorkerProc(lpStartAddress);
  start^.Address := Pointer(lpStartAddress);
  start^.Parameter := aParameter;

  id := 0;
  Result := BeginThread(tWorkerThreadTrampoline, start, id);
  lpThreadId := DWORD(id);

  // Issue #1041: Quiet suppresses this per-create debug line so the network
  // connect-retry loop (one thread every 5s while the server is unreachable)
  // does not spam the log -- loud on a genuine attempt, silent on retries.
  if not Quiet then
     begin
     logger.Debug('[tCreateThread] Created thread %d',[lpThreadId]);
     end;
end;

// _Pow10 and ValExt were DELETED here (Issue #997 finally closed).
//
// They were Borland RTL internals -- an FPU power-of-10 helper and a
// string-to-extended parser with a `code` error index -- carried as ~350 lines
// of x86-32 assembly. The comment that used to stand here said converting them
// needed a golden harness, because a CTY.DAT lat/lon regression silently
// corrupts every beam heading and distance.
//
// That harness turned out to be unnecessary: NOTHING CALLS THEM. uCTYDAT moved
// to the RTL `Val` intrinsic under Issue #1033 (see uctydat.pas around the Lat
// and Lon parses), and the only other references, in uCFG, were already
// commented out. _Pow10 was in turn called from nowhere but ValExt.
//
// So the safe conversion was a deletion. Checked before removing, not after.


function EnumerateLinesInFile(FileName: PAnsiChar; Func: TEnumLinesFunc; UpperCase: boolean): boolean;
label
  LastLine;
var
  (* THE FILE IS READ, NOT MEMORY-MAPPED (2026-09-07).

    It was CreateFileMapping + MapViewOfFile with two labels and two gotos to
    unwind three handles on a partial failure -- all Windows-only, and the RTL
    has no portable mapping. It is a TFileStream read into a TBytes now: one
    allocation, and the unwinding disappears with the handles.

    THE SCAN BELOW IS UNCHANGED. MapBase still walks bytes by index over the
    whole file exactly as it walked the mapped view; only where the bytes come
    from has changed. This is the same conversion, for the same reason, as
    uCTYDAT's. *)
  raw                                   : TBytes;
  fs                                    : TFileStream;
  FileSize                              : Cardinal;
  MapBase                               : PAnsiChar;
  StartPos, FilePos                     : Cardinal;
  TempString                            : ShortString;
  LineSize                              : integer;
  TempBuffer                            : array[0..255] of AnsiChar;
  NewLine                               : boolean;
begin
  Result := False;
  raw := nil;

  (* THE SAME THREE CANDIDATE PATHS as before -- as given, then under the log
    directory, then under the program directory -- but asked of the file
    system rather than of three open attempts. *)
  if strpos(FileName, '\') <> nil then
     begin
     Format(TempBuffer, '%s', FileName);
     end
  else
     begin
     Format(TempBuffer, '%s%s', TR4W_LOG_PATH_NAME, FileName);
     if not FileExists(TempBuffer) then
        begin
        Format(TempBuffer, '%s%s', TR4W_PATH_NAME, FileName);
        end;
     end;

  try
     fs := TFileStream.Create(AnsiString(TempBuffer), fmOpenRead or fmShareDenyNone);
     try
        SetLength(raw, fs.Size);
        if Length(raw) > 0 then
           begin
           fs.ReadBuffer(raw[0], Length(raw));
           end;
     finally
        fs.Free;
     end;
  except
     Exit;
  end;

  if Length(raw) = 0 then
     begin
     Exit;
     end;

  FileSize := Length(raw);
  MapBase := PAnsiChar(@raw[0]);

  Result := True;

  StartPos := 0;
  NewLine := False;
  FilePos := 0;

  while FilePos < FileSize do
     begin
     if (MapBase[FilePos] in [#13, #10]) then
        begin

        if not NewLine then
           begin
           LastLine:

           LineSize := FilePos - StartPos;
           if LineSize > 0 then
              begin
              FillChar(TempString, SizeOf(TempString), 0);
              TempString[0] := AnsiChar(LineSize);
              Move(MapBase[StartPos], TempString[1], LineSize);
              if UpperCase then
                 begin
                 strU(TempString);
                 end;
              //logger.debug('[TF.EnumerateLinesInFile] Reading config line %s',[TempString]);
              Func(@TempString);
              end;
           end;

        NewLine := True;

        end
     else
        begin
        if NewLine then
           begin
           NewLine := False;
           StartPos := FilePos;
           end;
        end;

     inc(FilePos);
     end;

  if not NewLine then
     begin
     // Issue #997: removed a bare `asm nop end;` no-op anchor (no codegen effect).
     goto LastLine;
     end;

  (* NOTHING TO UNWIND. This was UnmapViewOfFile / CloseHandle(MapFin) /
    CloseHandle(h), with labels 2 and 3 as the goto targets for a mapping that
    failed halfway. The stream is closed and `raw` is freed by the compiler. *)
end;




procedure strU(var Str: OpenString);
begin
  // Issue #997: extracted to uStrSearch (golden-master tested). Now 'var' to
  // make the in-place upcase contract explicit (the old by-value asm modified
  // the caller's string anyway -- see uStrSearch / the LogCfg note).
  uStrSearch.StrU(Str);
end;

(* THE MMTTY RICH EDIT, AND WINDOWS-ONLY WITH IT.

  Its one caller is uMMTTYForm, which hosts the RTTY engine's output. MMTTY is
  a separate Windows EXE and RICHED32 is a Windows control, so off Windows this
  function DOES NOT EXIST -- the declaration is gated too, which is what lets TF
  stop naming HWND in its interface. Its caller is gated to match, and
  MMTTY.mmttyEngine stays 0 there: the same "not running" state every MMTTY
  caller already handles. See uMMTTY's implementation gate. *)
{$IFDEF WINDOWS}
function CreateRichEdit(hwndParent: HWND): HWND;
begin
  Result := CreateWindowW('RichEdit', nil,
    ES_MULTILINE or ES_AUTOVSCROLL or ES_NOHIDESEL or ES_READONLY or ES_SAVESEL or WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or WS_HSCROLL,
    0, 0, 0, 0, hwndParent, 101, hInstance, nil);
  SendMessage(Result, WM_SETFONT, wParam(LucidaConsoleFont), 0);
end;
{$ENDIF}

function IntegerBetween(v: integer; i: integer; k: integer): boolean;
begin
   Result := (v >= i) and (v <= k);
end;

(* THIS BODY WAS ENTIRELY COMMENTED OUT, AND IT IS NOT DEAD CODE.

  Every statement was commented, so all four var parameters came back
  UNINITIALISED -- whatever happened to be on the stack. Pascal gives no
  warning for that and the compiler cannot: they are `var` parameters, so it
  assumes the callee writes them.

  IT MATTERS BECAUSE ITS TWO LIVE CALLERS BROADCAST THE RESULT. LOGEDIT's
  "Do you want to send time to computers on the network?" (two sites, 1845 and
  1968) calls this, then GetDate, then formats both into a MultiTimeMessage and
  sends it to every station in the multi-op network. GetDate IS implemented, so
  the message carried a correct date and a garbage time -- and the receiving
  stations set their clocks from it. In a contest, timestamps decide whether a
  QSO counts.

  Found 2026-09-05 while auditing TF for dead Win32 wrappers.

  UTC, deliberately, matching GetDate immediately above: it reads GetSystemTime,
  which is UTC, and a contest log is kept in UTC. The commented-out body agreed
  -- it read the UTC record -- so this restores the intent rather than choosing
  a new one.

  Sec100 is HUNDREDTHS, per the parameter name; wMilliseconds is thousandths.
  The old commented line assigned milliseconds straight across, which would
  have been wrong by a factor of ten had it ever run. No current caller reads
  Sec100, but a wrong value waiting to be used is not worth leaving. *)
(* THE UTC CLOCK, FROM THE RTL.

  Windows.GetSystemTime filled a SYSTEMTIME with UTC. LocalTimeToUniversal is
  the RTL's equivalent and works wherever FPC does; the fields are then
  decoded into the SAME record VC declares, so nothing downstream changes.

  wDayOfWeek IS 0-BASED IN WIN32 and SysUtils.DayOfWeek is 1-based (Sunday=1),
  hence the -1. Getting that wrong would be invisible until something indexed
  a day-name array. *)
procedure FillSystemTimeUTC(var St: SYSTEMTIME);
var
  utc: TDateTime;
  ms:  word;
begin
  utc := LocalTimeToUniversal(Now);
  DecodeDateTime(utc, St.wYear, St.wMonth, St.wDay,
                 St.wHour, St.wMinute, St.wSecond, ms);
  St.wMilliseconds := ms;
  St.wDayOfWeek    := DayOfWeek(utc) - 1;
end;

procedure GetTime(var Hour, Minute, Second, Sec100: Word);
var
  St                                    : SYSTEMTIME;
begin
  FillSystemTimeUTC(St);
  Hour := St.wHour;
  Minute := St.wMinute;
  Second := St.wSecond;
  Sec100 := St.wMilliseconds div 10;
end;

procedure GetDate(var Year, Month, Day, DayOfWeek: Word);
var
  St                                    : SYSTEMTIME;
begin
  //  DecodeDateFully(Date, Year, Month, Day, DayOfWeek);
  FillSystemTimeUTC(St);
  Year := St.wYear;
  Month := St.wMonth;
  Day := St.wDay;
  DayOfWeek := St.wDayOfWeek;
end;

function tOpenFileForRead(var h: THandle; FileName: PAnsiChar): boolean;
begin
  (* FileOpen, not CreateFileA: the RTL's, the same THandle, and the share
    mode spelled as fmShareDenyNone rather than FILE_SHARE_READ. It returns
    feInvalidHandle (-1) where CreateFileA returned INVALID_HANDLE_VALUE --
    the same value, under a name that is not Windows-only. *)
  h := FileOpen(AnsiString(FileName), fmOpenRead or fmShareDenyNone);
  Result := h <> THandle(feInvalidHandle);
end;

{
function StrLen(str: Pchar): cardinal;
asm
        MOV     EDI,EDX
        XOR     AL,AL
        MOV     ECX,0FFFFFFFFH
        REPNE   SCASB
        NOT     ECX
end;
}

(* THE Format FAMILY, NOW PASCAL AND NOT user32.

  Twenty overloads, each formerly `external user32 Name 'wsprintfA'` -- a
  direct binding to Win32's sprintf, called from 555 sites. They are why TF
  needed the Windows unit, and TF is reached by 171 units, so this was the
  single largest thing holding the tree to Windows.

  The forwards in the interface are unchanged, so no call site moved and the
  parameter keeps its name -- a body must match its forward. That second
  parameter being called `Format` shadows the function inside these bodies,
  which is exactly what is wanted: it IS the format string.

  The overloads exist because wsprintfA is variadic and Pascal is not: each
  pins an arity and a type list. They stay for that reason, and because they
  are what makes 555 call sites type-checked at all.

  uCFormat.CFormatBuf does the work -- see that unit for the one dialect
  difference that mattered (%02d) and why the callers were respelled instead
  of translated at run time. *)

function Format(Output: PAnsiChar; Format: PAnsiChar; c: AnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(c)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; s1: PAnsiChar; u1: integer; u2: integer; u3: integer; u4: integer; u5: integer; u6: integer; s2: PAnsiChar; s3: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(s1), u1, u2, u3, u4, u5, u6, AnsiString(s2), AnsiString(s3)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; p4: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), AnsiString(P2), AnsiString(p3), AnsiString(p4)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; p4: PAnsiChar; p5: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), AnsiString(P2), AnsiString(p3), AnsiString(p4), AnsiString(p5)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), AnsiString(P2), AnsiString(p3)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; i: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), AnsiString(P2), AnsiString(p3), i]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; i: integer; i2: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), AnsiString(P2), AnsiString(p3), i, i2]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; i: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), AnsiString(P2), i]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), AnsiString(P2)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer; i3: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [i, i2, i3]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer; p: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [i, i2, AnsiString(p)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [i]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [i, i2]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; p: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [i, AnsiString(p)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), i]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer; i2: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), i, i2]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer; P2: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(p), i, AnsiString(P2)]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; p: PAnsiChar; i2: integer): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [i, AnsiString(p), i2]);
end;

function Format(Output: PAnsiChar; Format: PAnsiChar; P1, P2, p3, p4, p5, p6, p7: PAnsiChar): integer;
begin
   Result := CFormatBuf(Output, AnsiString(Format), [AnsiString(P1), AnsiString(P2), AnsiString(p3), AnsiString(p4), AnsiString(p5), AnsiString(p6), AnsiString(p7)]);
end;

begin
  logger := TLogLogger.GetLogger('TR4WDebugLog.TF');   // own logger (was MainUnit.logger)
end.

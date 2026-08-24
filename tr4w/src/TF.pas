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
  Windows,
  SysUtils,
  ActiveX,
  Messages;

type
  TServerBrowseDialogA0 = function(HWND: HWND; pchBuffer: Pointer; cchBufSize: DWORD): BOOL; stdcall;

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

  TShellexecuteFunc = function(HWND: HWND; Operation, FileName, Parameters, Directory: PChar; showCmd: integer): hInst; stdcall;

  //function Shellexecute(HWND: HWND; Operation, FileName, Parameters, Directory: PChar; showCmd: integer): hInst; stdcall;
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

function CreateRichEdit(hwndParent: HWND): HWND;
function Createmsctls_progress32(X, Y, Width, Height: integer; hwndParent: HWND; HMENU: HMENU): HWND;

function CreateOwnerDrawListBox(dwStyle: DWORD; hwndParent: HWND): HWND;
function EnumerateLinesInFile(FileName: PAnsiChar; Func: TEnumLinesFunc; UpperCase: boolean): boolean;
function tGetDateFormat(DT: TQSOTime): PAnsiChar; //assembler;
procedure UnableToFindFileMessage(FileName: string);
function DeleteSlashes(p: PAnsiChar): PAnsiChar;
function SetParameterInArray(ArrayPtr: PInteger; ArrayLength: integer; aVar: PInteger; ValueToSet: integer): boolean;
function GetGUID: string;
function GetValueFromArray(PCharArrayAddress: PAnsiChar; ArraySize: Byte; const CMD: AnsiString): Byte;
function StrPosPartial(const Str1, Str2: PAnsiChar): PAnsiChar;
function GetDialogItemText(h: HWND; Control: integer): ShortString;
function GetNumberFromCharBuffer(p: PAnsiChar): integer;
procedure tLoadKeyboardLayout;
function StrComp_JOH_IA32_6(const Str1, Str2: PAnsiChar): integer;
function GetContestFromString(ContestString: ShortString): ContestType;
function STToInt64(St: SYSTEMTIME): int64;
function RealToStr2(Num: REAL): string;
function PCharToInt(p: PAnsiChar): integer;
function BooleanToStr(b: boolean): string;
//function CenterString(s: string; count: byte): string;
procedure strU(var Str: OpenString);
procedure SetMainWindowText(Window: TMainWindowElement; Text: string);
function IntegerBetween(v: integer; i: integer; k: integer): boolean;

// ValExt removed -- see the note at its old implementation site.  Callers use
// the RTL `Val` intrinsic, which is what uCTYDAT already does.

{ START A WORKER THREAD WHOSE FAULTS ARE NOT SILENT, AND WHOSE ALLOCATIONS ARE
  NOT A RACE.  Two defects, both measured on 2026-08-23, both fixed by routing
  through the RTL instead of calling CreateThread directly.  See the body. }
function tCreateThread(lpStartAddress: TFNThreadStartRoutine; var lpThreadId: DWORD; Quiet: boolean = False; aParameter: Pointer = nil): THandle;

//function tgethostbyname(h_Name: PAnsiChar): PAnsiChar;
function tDialogBox(WindowID: Byte; WinProcAdr: Pointer): integer;
function tWM_SETFONT(h: HWND; Font: HFONT): HWND;
procedure tLB_SETCOLUMNWIDTH(h: HWND; Width: integer);
function tLB_GETCURSEL(h: HWND): integer;
function tLB_SETCURSEL(h: HWND; pos: wParam): integer;
procedure tCB_SETCURSEL(ParentHandle: HWND; Control: integer; pos: Cardinal);
procedure tCB_ADDSTRING(ParentHandle: HWND; Control: integer; s: string);
procedure tCB_ADDSTRING_PCHAR(ParentHandle: HWND; Control: integer; s: string);
function tLB_ADDSTRING(h: HWND; Text: PAnsiChar): integer;
function tLB_RESETCONTENT(h: HWND): integer;
function tCB_GETCURSEL(ParentHandle: HWND; Control: integer): integer;

procedure tSetWindowText(WindowHandle: HWND; s: string);
procedure tSetWindowRedraw(wnd: HWND; Redraw: boolean);
function SystemTimeToString(SysTime: SYSTEMTIME): string;
procedure SelectParentDir(h: HWND);

//function StrLen(const Str: PChar): Cardinal;
function tWindowsExist(wID: WindowsType): boolean;

function GetWindowByHandle(h: HWND): WindowsType;

procedure tEnableMenuItem(uIDEnableItem: UINT; uEnable: UINT);


procedure showwarning(Text: string);
procedure ShowSysErrorMessage(ID: PAnsiChar);


//function tr4w_GetTimeString: PChar;
function RITFreqToPchar(i: integer): string;
function FreqToPChar(i: integer): string;
function FreqToPChar2(i: integer): string;
function FreqToPCharWithoutHZ(i: integer): string;
function kHzToPChar(Freq: Word): string;
//function InitSysMonthCal32: boolean;
function MillisecondsToFormattedString(msecs: Cardinal; WithMsec: boolean): string;

//function Pos(Substr: string; S: string): Integer;
function ArrayToString(const a: array of Char): string;
procedure InvertBoolean(var b: boolean);
function inttopchar(i: integer): PAnsiChar;
procedure DragWindow(h: HWND);
//procedure SaveStructure(Address: Pointer; Count: integer; FileName: string);
procedure EnableWindowTrue(h: HWND; nIDDlgItem: integer);
procedure EnableWindowFalse(h: HWND; nIDDlgItem: integer);
function _StrInt64(Val: int64; Width: integer): ShortString;
function ShowServerDialog(AHandle: THandle): string;
//function tShellexecute(HWND: HWND; Operation, FileName, Parameters, Directory: PChar; showCmd: integer): hInst; // 4.75.3
function tSetDlgItemIntFalse(hDlg: HWND; nIDDlgItem: integer; uValue: UINT): BOOL; stdcall;
function tSetDlgItemIntSigned(hDlg: HWND; nIDDlgItem: integer; uValue: integer): BOOL; stdcall;
function CreateModalDialog(Width, Height: integer; ParentHWND: HWND; lpDialogFunc: TFNDlgProc; dwInitParam: lParam): integer;
function CreateListBox(X, Y, nWidth, nHeight: Word; hwndParent: HWND; HMENU: HMENU): HWND;
function CreateButton(dwStyle: Cardinal; lpWindowName: PAnsiChar; X, Y, nWidth: integer; hwndParent: HWND; HMENU: HMENU): HWND;
function CreateStatic(lpWindowName: PAnsiChar; X, Y, nWidth: integer; hwndParent: HWND; HMENU: HMENU): HWND;
function CreateEdit(dwStyle: Cardinal; X, Y, Width, Height: integer; hwndParent: HWND; HMENU: HMENU): HWND;
function CreateListView2(X, Y, nWidth, nHeight: Word; hwndParent: HWND): HWND;
function CreateComboBox(hwndParent: HWND; HMENU: HMENU): HWND;
function SendDlgItemMessage(hDlg: HWND; nIDDlgItem: integer; Msg: UINT): LONGINT; stdcall;

function tOpenFileForRead(var h: HWND; FileName: PAnsiChar): boolean;

procedure GetTime(var Hour, Minute, Second, Sec100: Word);
procedure GetDate(var Year, Month, Day, DayOfWeek: Word);

{$EXTERNALSYM Format}
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

uses Log4D, uFreqTimeFormat, uStrSearch, uAnsiStr,   // Issue #997: freq/time formatters + PChar search helpers extracted + golden-tested
     uCrashLog;   // LogCaughtException -- see tCreateThread

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
function Format(Output: PAnsiChar; Format: PAnsiChar; c: AnsiChar): integer; external user32 Name 'wsprintfA';

function Format(Output: PAnsiChar; Format: PAnsiChar; s1: PAnsiChar; u1: integer; u2: integer; u3: integer; u4: integer; u5: integer; u6: integer; s2: PAnsiChar; s3: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; p4: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; p4: PAnsiChar; p5: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; i: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; p3: PAnsiChar; i: integer; i2: integer): integer; external user32 Name 'wsprintfA';

function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar; i: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; P2: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar): integer; external user32 Name 'wsprintfA';

function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer; i3: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer; p: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; i2: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; p: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer; i2: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; p: PAnsiChar; i: integer; P2: PAnsiChar): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; i: integer; p: PAnsiChar; i2: integer): integer; external user32 Name 'wsprintfA';
function Format(Output: PAnsiChar; Format: PAnsiChar; P1, P2, p3, p4, p5, p6, p7: PAnsiChar): integer; external user32 Name 'wsprintfA';
//uses mainunit;

// SysErrorMessage removed (D12): use SysUtils.SysErrorMessage (returns a
// trimmed string). TF's version was a duplicate that returned PAnsiChar into a
// static buffer, untrimmed; the trailing-CRLF difference is cosmetic.

procedure showwarning(Text: string);
begin
  logger.Warn(Text);
  // Silent/batch export (/EXPORT) runs headless with no operator to dismiss a
  // modal -- a MessageBox would block the run indefinitely (e.g. the ARRL10 /
  // Winter Field Day "LOCATION field is empty" check in PostUnit). The warning
  // is already in the log above; skip the modal in that mode.
  if tSilentExport then Exit;
  MessageBoxW(0, PChar(Text), 'TR4W', MB_OK or MB_ICONWARNING or MB_SYSTEMMODAL or MB_TOPMOST);
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

function kHzToPChar(Freq: Word): string;
begin
  Result := uFreqTimeFormat.kHzToPChar(Freq);   // Issue #997: extracted
end;

function ArrayToString(const a: array of Char): string;
begin
  if Length(a)>0 then
    // Genuinely wide on both sides: under D12 `Char` IS WideChar and Result is
    // a UnicodeString, so PChar here is PWideChar and the element stride
    // matches.  Do not "fix" this one to PAnsiChar.
     begin
     SetString(Result, PChar(@a[0]), Length(a))   // lint:wide-ok
     end
  else
     begin
     Result := '';
     end;
end;

{
}

function GetGUID: string;   // Returns 32-char lowercase hex, no dashes or braces
var
   MyGUID: TGUID;
begin
   Result := '';
   if CreateGUID(MyGUID) <> S_OK then
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


procedure DragWindow(h: HWND);
begin
  PostMessage(h, WM_SYSCOMMAND, $F012, 0);
end;

function tWM_SETFONT(h: HWND; Font: HFONT): HWND;
begin
  SendMessage(h, WM_SETFONT, wParam(Font), 0);
  Result := h;
end;

procedure tLB_SETCOLUMNWIDTH(h: HWND; Width: integer);
begin
  if h = 0 then Exit;
  Windows.SendDlgItemMessage(h, 101, LB_SETCOLUMNWIDTH, wParam(Width), 0);
end;

function tLB_GETCURSEL(h: HWND): integer;
begin
  Result := SendMessage(h, LB_GETCURSEL, 0, 0);
end;

function tLB_SETCURSEL(h: HWND; pos: wParam): integer;
begin
  Result := SendMessage(h, LB_SETCURSEL, pos, 0);
end;

procedure tCB_SETCURSEL(ParentHandle: HWND; Control: integer; pos: Cardinal);
begin
  Windows.SendDlgItemMessage(ParentHandle, integer(Control), CB_SETCURSEL, wParam(pos), 0);
end;

function tCB_GETCURSEL(ParentHandle: HWND; Control: integer): integer;
begin
  Result := SendDlgItemMessage(ParentHandle, integer(Control), CB_GETCURSEL);
end;

procedure tCB_ADDSTRING(ParentHandle: HWND; Control: integer; s: string);
begin
  Windows.SendDlgItemMessageW(ParentHandle, integer(Control), CB_ADDSTRING, 0, LPARAM(PChar(s)));
end;

procedure tCB_ADDSTRING_PCHAR(ParentHandle: HWND; Control: integer; s: string);
begin
  Windows.SendDlgItemMessageW(ParentHandle, integer(Control), CB_ADDSTRING, 0, LPARAM(PChar(s)));
end;

function tLB_ADDSTRING(h: HWND; Text: PAnsiChar): integer;
begin
  Result := -1;
  if h = 0 then Exit;
  Result := SendMessageA(h, LB_ADDSTRING, 0, integer(Text));
end;

function tLB_RESETCONTENT(h: HWND): integer;
begin
  if h = 0 then Exit;
  Result := SendMessage(h, LB_RESETCONTENT, 0, 0);
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

procedure EnableWindowTrue(h: HWND; nIDDlgItem: integer);
begin
  Windows.EnableWindow(GetDlgItem(h, nIDDlgItem), True);
end;

procedure EnableWindowFalse(h: HWND; nIDDlgItem: integer);
begin
  Windows.EnableWindow(GetDlgItem(h, nIDDlgItem), False);
end;

{From System}

function _StrInt64(Val: int64; Width: integer): ShortString;
var
  d                                     : array[0..31] of AnsiChar; { need 19 digits and a sign }
  i, k                                  : integer;
  sign                                  : boolean;
  spaces                                : integer;
begin
  { Produce an ASCII representation of the number in reverse order }

  Windows.ZeroMemory(@Result, SizeOf(Result));
  i := 0;
  sign := Val < 0;
  repeat
    d[i] := AnsiChar(Abs(Val mod 10) + Ord('0'));
    inc(i);
    Val := Val div 10;
  until Val = 0;
  if sign then
     begin
     d[i] := '-';
     inc(i);
     end;

  { Fill the Result with the appropriate number of blanks }
  if Width > 255 then
     begin
     Width := 255;
     end;
  k := 1;
  spaces := Width - i;
  while k <= spaces do
     begin
     Result[k] := ' ';
     inc(k);
     end;

  { Fill the Result with the number }
  while i > 0 do
     begin
     dec(i);
     Result[k] := d[i];
     inc(k);
     end;

  { Result is k-1 characters long }
  SetLength(Result, k - 1);

end;

function ShowServerDialog(AHandle: THandle): string;
var
  ServerBrowseDialogA0                  : TServerBrowseDialogA0;
  LANMAN_DLL                            : DWORD;
  Buffer                                : array[0..256] of AnsiChar;
  bLoadLib                              : boolean;
begin
  LANMAN_DLL := GetModuleHandle('NTLANMAN.DLL');
  if LANMAN_DLL = 0 then
     begin
     LANMAN_DLL := LoadLibrary('NTLANMAN.DLL');
     bLoadLib := True;
     end;
  if LANMAN_DLL <> 0 then
     begin
     @ServerBrowseDialogA0 := GetProcAddress(LANMAN_DLL, {'ShareAsDialogA0'} 'ServerBrowseDialogA0');
     ServerBrowseDialogA0(AHandle, @Buffer, 256);
       //         if Buffer[0] = '\' then
     begin
       Result := Buffer;
     end;
     if bLoadLib then
        begin
        FreeLibrary(LANMAN_DLL);
        end;
     end;
end;

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
var
  TEMPFILETIME                          : FILETIME;
begin
  Windows.SystemTimeToFileTime(St, TEMPFILETIME);
  Result := int64(TEMPFILETIME);
  Result := round(Result / 10000);
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

procedure tSetWindowText(WindowHandle: HWND; s: string);
begin
  { Cast to AnsiString at the boundary rather than letting the compiler do it.
    This deliberately calls the A variant, as the rest of the program does, but
    PChar is PWideChar under D12 -- so today this resolves to the AnsiString
    overload of SetWindowTextA via an IMPLICIT PWideChar->AnsiString conversion
    (W1057).  Same bytes reach Windows either way; making it explicit says the
    narrowing is intended and compiles under FPC, whose RTL offers only the
    LPCSTR form. }
  Windows.SetWindowTextA(WindowHandle, PAnsiChar(AnsiString(s)));
end;

procedure tSetWindowRedraw(wnd: HWND; Redraw: boolean);
begin
  SendMessage(wnd, WM_SETREDRAW, integer(Redraw), 0);
end;

function SystemTimeToString(SysTime: SYSTEMTIME): string;
begin
  // Issue #997: extracted to uFreqTimeFormat (golden-master tested).
  Result := uFreqTimeFormat.SystemTimeToString(SysTime);
end;

function StrComp_JOH_IA32_6(const Str1, Str2: PAnsiChar): integer;
begin
  // Issue #997: extracted to uStrSearch (golden-master tested).
  Result := uStrSearch.StrComp_JOH_IA32_6(Str1, Str2);
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
{
procedure tSetDlgItemTypText(hDlg: HWND; nIDDlgItem: integer; lpString: PChar);
begin
  Windows.CopyMemory(@SetDlgItemTextBuffer, lpString + 1, Cardinal(lpString^));
  SetDlgItemTextBuffer[Cardinal(lpString^)] := #0;
  Windows.SetDlgItemTextA(hDlg, nIDDlgItem, SetDlgItemTextBuffer);
end;
}

function GetContestFromString(ContestString: ShortString): ContestType;
var
  TempContest                           : ContestType;
begin
  ContestString[Ord(ContestString[0]) + 1] := #0;
  for TempContest := Succ(DUMMYCONTEST) to High(ContestType) do
    if Windows.lstrcmpA(ContestTypeSA[TempContest], @ContestString[1]) = 0 then
       begin
       Result := TempContest;
       Exit;
       end;
  Result := DUMMYCONTEST;
end;

function GetDialogItemText(h: HWND; Control: integer): ShortString;
var
  Len                                   : integer;
  TempHWND                              : HWND;
begin

  if Control = -1 then
     begin
     TempHWND := h
     end
  else
     begin
     TempHWND := Windows.GetDlgItem(h, Control);
     end;
  Len := Windows.SendMessageA(TempHWND, WM_GETTEXTLENGTH, 0, 0);
  Windows.ZeroMemory(@Result, SizeOf(Result));
  SetLength(Result, Len);
  if Len <> 0 then
     begin
     Windows.SendMessageA(TempHWND, WM_GETTEXT, Len + 1, LONGINT(Pointer(@Result[1])));
     end;
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

function tSetDlgItemIntFalse(hDlg: HWND; nIDDlgItem: integer; uValue: UINT): BOOL; stdcall;
begin
  Windows.SetDlgItemInt(hDlg, nIDDlgItem, uValue, False);
end;

function tSetDlgItemIntSigned(hDlg: HWND; nIDDlgItem: integer; uValue: integer): BOOL; stdcall;
begin
  Windows.SetDlgItemInt(hDlg, nIDDlgItem, uValue, True);
end;

function GetWindowByHandle(h: HWND): WindowsType;
var
  wt                                    : WindowsType;
begin
  for wt := Low(WindowsType) to High(WindowsType) do
    if tr4w_WindowsArray[wt].WndHandle = h then
       begin
       Result := wt;
       Break;
       end;
end;

function tWindowsExist(wID: WindowsType): boolean;
begin
  Result := tr4w_WindowsArray[wID].WndHandle <> 0;
end;

procedure tEnableMenuItem(uIDEnableItem: UINT; uEnable: UINT);
begin
  EnableMenuItem(tr4w_main_menu, uIDEnableItem, uEnable);
  DrawMenuBar(tr4whandle);
end;



function StrPosPartial(const Str1, Str2: PAnsiChar): PAnsiChar;
begin
  // Issue #997: extracted to uStrSearch (golden-master tested).
  Result := uStrSearch.StrPosPartial(Str1, Str2);
end;

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

  Format(GetDateFormatBuffer, '%02d-%02d-%02d', dt.qtDay, DT.qtMonth, DT.qtYear);
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
  showwarning(SysUtils.Format('%s: %s', [string(ID), SysUtils.SysErrorMessage(Windows.GetLastError)]));
end;

procedure SelectParentDir(h: HWND);
var
  i                                     : integer;
const
  c                                     = '[..]';
begin
  i := Windows.SendMessageA(h, LB_FINDSTRING, -1, integer(PAnsiChar(c)));
  if i <> LB_ERR then
     begin
     Windows.SendMessage(h, LB_DELETESTRING, i, 0);
     Windows.SendMessageA(h, LB_INSERTSTRING, 0, integer(PAnsiChar(c)));
     end;
  tLB_SETCURSEL(h, 0);
end;

function tDialogBox(WindowID: Byte; WinProcAdr: Pointer): integer;
var
  hwndParent                            : HWND;
begin
  hwndParent := tr4whandle;
  if CreateCabrilloWindow <> 0 then
     begin
     hwndParent := CreateCabrilloWindow;
     end;
  Result := DialogBox(hInstance, MAKEINTRESOURCE(WindowID), hwndParent, WinProcAdr);
//  Result := DialogBoxParamW(hInstance, MakeIntResourceW(WindowID), hwndParent, WinProcAdr, 0);

  //  SendMessage(Result, WM_SETICON, ICON_BIG, LoadIcon(thInstance, 'MAINICON'));
end;

procedure SetMainWindowText(Window: TMainWindowElement; Text: string);
begin
  // D12: Text is native string; empty ('') is the "clear" signal that nil/#0
  // used to be.  Write via the W-API so the whole path is Unicode.
  if (Text = '') then
    if TWindows[Window].mweE then
       begin
       Exit;
       end;
  Windows.SetWindowTextW(wh[Window], PChar(Text));

  TWindows[Window].mweE := (Text = '');
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

function tCreateThread(lpStartAddress: TFNThreadStartRoutine; var lpThreadId: DWORD; Quiet: boolean; aParameter: Pointer): THandle;
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
// to the RTL `Val` intrinsic under Issue #1033 (see uCTYDAT.PAS around the Lat
// and Lon parses), and the only other references, in uCFG, were already
// commented out. _Pow10 was in turn called from nowhere but ValExt.
//
// So the safe conversion was a deletion. Checked before removing, not after.


function EnumerateLinesInFile(FileName: PAnsiChar; Func: TEnumLinesFunc; UpperCase: boolean): boolean;
label
  2, 3, LastLine;
var
  h                                     : HWND;
  FileSize                              : Cardinal;
  MapFin                                : Cardinal;
  MapBase                               : PAnsiChar;
  StartPos, FilePos                     : Cardinal;
  TempString                            : ShortString;
  LineSize                              : integer;
  TempBuffer                            : array[0..255] of AnsiChar;
  NewLine                               : boolean;
begin
  Result := False;

  if strpos(FileName, '\') <> nil then
     begin
     tOpenFileForRead(h, FileName)
     end
  else
     begin
     Format(TempBuffer, '%s%s', TR4W_LOG_PATH_NAME, FileName);
     if not tOpenFileForRead(h, TempBuffer) then
        begin
        Format(TempBuffer, '%s%s', TR4W_PATH_NAME, FileName);
        tOpenFileForRead(h, TempBuffer);
        end;
     end;

  if h = INVALID_HANDLE_VALUE then Exit;

  FileSize := Windows.GetFileSize(h, nil);
  MapFin := Windows.CreateFileMapping(h, nil, PAGE_READONLY, 0, 0, nil);
  if MapFin = 0 then
     begin
     goto 2;
     end;

  MapBase := Windows.MapViewOfFile(MapFin, FILE_MAP_READ, 0, 0, 0);

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
              Windows.ZeroMemory(@TempString, SizeOf(TempString));
              TempString[0] := AnsiChar(LineSize);
              Windows.CopyMemory(@TempString[1], @MapBase[StartPos], LineSize);
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

  Windows.UnmapViewOfFile(MapBase);
  3:
  CloseHandle(MapFin);
  2:
  CloseHandle(h);
end;




function CreateModalDialog(Width, Height: integer; ParentHWND: HWND; lpDialogFunc: TFNDlgProc; dwInitParam: lParam): integer;
type
  TDLGTEMPLATEEX = packed record
    dlgVer: Word;
    signature: Word;
    helpID: DWORD;
    exStyle: DWORD;
    Style: DWORD;
    cDlgItems: Word;
    X: Word;
    Y: Word;
    cx: Word;
    cy: Word;
    Menu: Word;
    windowClass: Word;
    Title: LPWSTR;
    ttt: array[0..127 - 5] of AnsiChar;
  end;
  PDLGTEMPLATEEX = ^TDLGTEMPLATEEX;

const
  ms                                    = DS_SETFONT or DS_CENTER or WS_SYSMENU or DS_MODALFRAME or WS_CAPTION or WS_VISIBLE;

var
//  tempDLGTEMPLATE                       : MYDLGTEMPLATE;
  tempDLGTEMPLATEex                     : TDLGTEMPLATEEX;
  p                                     : PDlgTemplate;
 
begin
  p := @ {tempDLGTEMPLATEex } tempDLGTEMPLATE;

  Windows.ZeroMemory(@tempDLGTEMPLATE, SizeOf(tempDLGTEMPLATE));
  Windows.ZeroMemory(@tempDLGTEMPLATEex, SizeOf(tempDLGTEMPLATEex));
{
  tempDLGTEMPLATEex.dlgVer := $ffff;
  tempDLGTEMPLATEex.signature := 1;
  tempDLGTEMPLATEex.cx := Width;
  tempDLGTEMPLATEex.cy := Height;
  tempDLGTEMPLATEex.Style := DS_SETFONT or DS_CENTER or WS_SYSMENU or DS_MODALFRAME or WS_CAPTION or WS_VISIBLE;
//  tempDLGTEMPLATEex.cDlgItems:
}

  tempDLGTEMPLATE.X := 10;
  tempDLGTEMPLATE.Y := 10;

  tempDLGTEMPLATE.cx := Width;
  tempDLGTEMPLATE.cy := Height;
  tempDLGTEMPLATE.Style := DS_SETFONT or DS_CENTER or WS_SYSMENU or DS_MODALFRAME or WS_CAPTION or WS_VISIBLE;

  Result := DialogBoxIndirectParam(hInstance, p^, ParentHWND, lpDialogFunc, dwInitParam);

//  if Result = -1 then MessageBox(0, SysErrorMessage(GetLastError), nil, MB_OK or MB_ICONINFORMATION {or MB_RTLREADING } or MB_TASKMODAL);
end;

procedure strU(var Str: OpenString);
begin
  // Issue #997: extracted to uStrSearch (golden-master tested). Now 'var' to
  // make the in-place upcase contract explicit (the old by-value asm modified
  // the caller's string anyway -- see uStrSearch / the LogCfg note).
  uStrSearch.StrU(Str);
end;

function CreateComboBox(hwndParent: HWND; HMENU: HMENU): HWND;
begin
  Result := CreateWindowExW(WS_EX_STATICEDGE, COMBOBOX, nil,

    CBS_DROPDOWN or CBS_AUTOHSCROLL or CBS_SORT or CBS_HASSTRINGS or WS_CHILD or WS_VISIBLE or WS_VSCROLL or WS_TABSTOP

    , 0, 0, 0, 23, hwndParent, HMENU, hInstance, nil);
  tWM_SETFONT(Result, MSSansSerifFont);
end;

function CreateListView2(X, Y, nWidth, nHeight: Word; hwndParent: HWND): HWND;
begin
  Result := CreateWindowExW(WS_EX_STATICEDGE, LISTVIEW, nil, LVS_REPORT or LVS_SINGLESEL or LVS_SHOWSELALWAYS or LVS_NOSORTHEADER or WS_VISIBLE or WS_CHILD or WS_TABSTOP, X, Y, nWidth, nHeight, hwndParent, 101, hInstance, nil);
  tWM_SETFONT(Result, MSSansSerifFont);
end;

function CreateListBox(X, Y, nWidth, nHeight: Word; hwndParent: HWND; HMENU: HMENU): HWND;
begin
  Result := CreateWindowExW(WS_EX_STATICEDGE, LISTBOX, nil, LBS_NOINTEGRALHEIGHT or LBS_NOTIFY or LBS_SORT or WS_VSCROLL or WS_VISIBLE or WS_CHILD or WS_TABSTOP, X, Y, nWidth, nHeight, hwndParent, HMENU, hInstance, nil);
  tWM_SETFONT(Result, MSSansSerifFont);
end;

function CreateStatic(lpWindowName: PAnsiChar; X, Y, nWidth: integer; hwndParent: HWND; HMENU: HMENU): HWND;
begin
  Result := CreateWindowA('Static', lpWindowName, SS_SUNKEN or SS_center or WS_CHILD or WS_VISIBLE, X, Y, nWidth, 23 {nHeight}, hwndParent, HMENU, hInstance, nil);
  tWM_SETFONT(Result, MSSansSerifFont);
end;

function CreateButton(dwStyle: Cardinal; lpWindowName: PAnsiChar; X, Y, nWidth: integer; hwndParent: HWND; HMENU: HMENU): HWND;
begin
  Result := CreateWindowExA(0, 'Button', lpWindowName, dwStyle or WS_CHILD or BS_TEXT or WS_VISIBLE or WS_TABSTOP, X, Y, nWidth, 23 {nHeight}, hwndParent, HMENU, hInstance, nil);
  tWM_SETFONT(Result, MSSansSerifFont);
end;

function CreateEdit(dwStyle: Cardinal; X, Y, Width, Height: integer; hwndParent: HWND; HMENU: HMENU): HWND;
begin
  Result := CreateWindowExW(WS_EX_CLIENTEDGE or WS_EX_NOPARENTNOTIFY, EditPChar, nil, dwStyle or WS_CHILD or WS_VISIBLE or WS_TABSTOP, X, Y, Width, Height, hwndParent, HMENU, hInstance, nil);
  tWM_SETFONT(Result, MSSansSerifFont);
end;

function CreateOwnerDrawListBox(dwStyle: DWORD; hwndParent: HWND): HWND;
begin
  Result := CreateWindowExW(WS_EX_STATICEDGE, LISTBOX, nil, dwStyle, 0, 0, 0, 0, hwndParent, 101, hInstance, nil);
  tWM_SETFONT(Result, MSSansSerifFont);
end;

function Createmsctls_progress32(X, Y, Width, Height: integer; hwndParent: HWND; HMENU: HMENU): HWND;
begin
  Result := CreateWindowW('msctls_progress32', nil, WS_CHILD or WS_VISIBLE or PBS_SMOOTH, X, Y, Width, Height, hwndParent, HMENU, hInstance, nil);
end;

function CreateRichEdit(hwndParent: HWND): HWND;
begin
  Result := CreateWindowW('RichEdit', nil,
    ES_MULTILINE or ES_AUTOVSCROLL or ES_NOHIDESEL or ES_READONLY or ES_SAVESEL or WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or WS_HSCROLL,
    0, 0, 0, 0, hwndParent, 101, hInstance, nil);
  tWM_SETFONT(Result, LucidaConsoleFont);
end;

function SendDlgItemMessage(hDlg: HWND; nIDDlgItem: integer; Msg: UINT): LONGINT; stdcall;
begin
  Result := Windows.SendDlgItemMessage(hDlg, nIDDlgItem, Msg, 0, 0);
end;

function IntegerBetween(v: integer; i: integer; k: integer): boolean;
begin
   Result := (v >= i) and (v <= k);
end;

procedure GetTime(var Hour, Minute, Second, Sec100: Word);
begin
  //DecodeTime(Now, Hour, Minute, Second, Sec100);
{
  tGetSystemTime;
  Hour := UTC.wHour;
  Minute := UTC.wMinute;
  Second := UTC.wSecond;
  Sec100 := UTC.wMilliseconds;
}
end;

procedure GetDate(var Year, Month, Day, DayOfWeek: Word);
var
  St                                    : SYSTEMTIME;
begin
  //  DecodeDateFully(Date, Year, Month, Day, DayOfWeek);
  GetSystemTime(St);
  Year := St.wYear;
  Month := St.wMonth;
  Day := St.wDay;
  DayOfWeek := St.wDayOfWeek;
end;

function tOpenFileForRead(var h: HWND; FileName: PAnsiChar): boolean;
begin
  h := CreateFileA(FileName, GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_ARCHIVE, 0);
  Result := h <> INVALID_HANDLE_VALUE;
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
begin
  logger := TLogLogger.GetLogger('TR4WDebugLog.TF');   // own logger (was MainUnit.logger)
end.

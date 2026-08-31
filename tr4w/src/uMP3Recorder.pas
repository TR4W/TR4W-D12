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
unit uMP3Recorder;
{$I tr4w.inc}

interface
uses
//  spectrum_vis,
  LogK1EA,
  SysUtils, // Issue #997 (StrPCopy/Format for asm-block removal; placed before TF so unqualified Format still resolves to TF.Format)
  uAnsiStr, // D12: ANSI StrPCopy (before TF so unqualified Format still resolves to TF.Format)
  TF,
  Version,
  VC,
  LogWind,
  PostUnit,
  LogDupe,
  utils_file,
  MMSystem,
  Windows,
  Tree,
  Messages
  ,
  uTR4WStrings;
type
  TMP3RecorderDuration = (rdEachQSO, rdEachHour, rdNonStop);
  {(*}
  TID3Rec = packed record
    Tag     : array[0..2] of AnsiChar;
    Title   : array[0..29] of AnsiChar;
    Artist  : array[0..29] of AnsiChar;
    Album   : array[0..29] of AnsiChar;
    Year    : array[0..3] of AnsiChar;
    comment : array[0..29] of AnsiChar;
    Genre   : Byte;
  end;
{*)}
type
  THBE_STREAM = longword;
  PHBE_STREAM = ^THBE_STREAM;
  BE_ERR = longword;

const

// List of valid bitrates[kbps]& sample frequencies[hz].
// first Index
// 0 : MPEG - 2 values(sample frequencies 16...24 kHz)
// 1 : MPEG - 1 values(sample frequencies 32...48 kHz)
// 2 : MPEG - 2.5 values(sample frequencies 8...12 kHz)
  MPEG1                                 = 1;
  MPEG2                                 = 0;
  MPEG25                                = 2;

   // encoding formats
  BE_CONFIG_MP3                         = 0;
  BE_CONFIG_LAME                        = 256;

  LQP_NOPRESET                          = -1;

   // QUALITY PRESETS
  LQP_NORMAL_QUALITY                    = 0;
  LQP_LOW_QUALITY                       = 1;
  LQP_HIGH_QUALITY                      = 2;
  LQP_VOICE_QUALITY                     = 3;
  LQP_R3MIX                             = 4;
  LQP_VERYHIGH_QUALITY                  = 5;
  LQP_STANDARD                          = 6;
  LQP_FAST_STANDARD                     = 7;
  LQP_EXTREME                           = 8;
  LQP_FAST_EXTREME                      = 9;
  LQP_INSANE                            = 10;
  LQP_ABR                               = 11;
  LQP_CBR                               = 12;
  LQP_MEDIUM                            = 13;
  LQP_FAST_MEDIUM                       = 14;
   // NEW PRESET VALUES
  LQP_PHONE                             = 1000;
  LQP_SW                                = 2000;
  LQP_AM                                = 3000;
  LQP_FM                                = 4000;
  LQP_VOICE                             = 5000;
  LQP_RADIO                             = 6000;
  LQP_TAPE                              = 7000;
  LQP_HIFI                              = 8000;
  LQP_CD                                = 9000;
  LQP_STUDIO                            = 10000;

  BE_ERR_SUCCESSFUL                     : longword = 0;
  BE_ERR_INVALID_FORMAT                 : longword = 1;
  BE_ERR_INVALID_FORMAT_PARAMETERS      : longword = 2;
  BE_ERR_NO_MORE_HANDLES                : longword = 3;
  BE_ERR_INVALID_HANDLE                 : longword = 4;
   // other constants
  BE_MAX_HOMEPAGE                       = 256;
   // format specific variables

  BE_MP3_MODE_STEREO                    = 0;
  BE_MP3_MODE_JSTEREO                   = 1;
  BE_MP3_MODE_DUALCHANNEL               = 2;
  BE_MP3_MODE_MONO                      = 3;

const
  VBR_METHOD_NONE                       = -1;
  VBR_METHOD_DEFAULT                    = 0;
  VBR_METHOD_OLD                        = 1;
  VBR_METHOD_NEW                        = 2;
  VBR_METHOD_MTRH                       = 3;
  VBR_METHOD_ABR                        = 4;
type
  MCI_DGV_OPEN_PARMS = record
    dwCallback: PDWORD;
    wDeviceID: UINT;
    lpstrDeviceType: LPTSTR;
    lpstrElementName: LPTSTR;
    lpstrAlias: LPTSTR;
    dwStyle: DWORD;
    hwndParent: HWND;
  end;

const

  MCI_DGV_OPEN_WS                       = $00010000;
  MCI_DGV_OPEN_PARENT                   = $00020000;
  MCI_DGV_OPEN_NOSTATIC                 = $00040000;
  MCI_DGV_OPEN_16BIT                    = $00080000;
  MCI_DGV_OPEN_32BIT                    = $00100000;

  MP3RecorderDurationSA                 : array[TMP3RecorderDuration] of PAnsiChar = ('EACH QSO', 'EACH HOUR', 'NON-STOP');
  Freq                                  = 11025;
  bufsize                               = Freq * 2;
  PeakProgressBarMaxValue               = 45;

type
  TMP3 = packed record
    dwSampleRate: DWORD;
    byMode: Byte;
    wBitRate: Word;
    bPrivate: BOOL;
    bCRC: BOOL;
    bCopyright: BOOL;
    bOriginal: BOOL;
  end;

  TLHV1 = packed record

    dwStructVersion: DWORD;
    dwStructSize: DWORD;

    dwSampleRate: DWORD; // SAMPLERATE OF INPUT FILE
    dwReSampleRate: DWORD; // DOWNSAMPLERATE, 0=ENCODER DECIDES
    nMode: longword; // BE_MP3_MODE_STEREO, BE_MP3_MODE_DUALCHANNEL, BE_MP3_MODE_MONO
    dwBitrate: DWORD; // CBR bitrate, VBR min bitrate
    dwMaxBitrate: DWORD; // CBR ignored, VBR Max bitrate
    nPreset: longword; // Quality preset, use one of the settings of the LAME_QUALITY_PRESET enum
    dwMpegVersion: DWORD; // FUTURE USE, MPEG-1 OR MPEG-2
    dwPsyModel: DWORD; // FUTURE USE, SET TO 0
    dwEmphasis: DWORD; // FUTURE USE, SET TO 0
      // BIT STREAM SETTINGS
    bPrivate: boolean; // Set Private Bit (TRUE/FALSE)
    bCRC: boolean; // Insert CRC (TRUE/FALSE)
    bCopyright: boolean; // Set Copyright Bit (TRUE/FALSE)
    bOriginal: boolean; // Set Original Bit (TRUE/FALSE)
      // VBR STUFF
    bWriteVBRHeader: boolean; // WRITE XING VBR HEADER (TRUE/FALSE)
    bEnableVBR: boolean; // USE VBR ENCODING (TRUE/FALSE)
    nVBRQuality: integer; // VBR QUALITY 0..9
    dwVbrAbr_bps: DWORD; // Use ABR in stead of nVBRQuality
    nVbrMethod: SHORTINT;
    bNoRes: boolean; // Disable Bit resorvoir (TRUE/FALSE)
      // MISC SETTINGS
    bStrictIso: boolean; // Use strict ISO encoding rules (TRUE/FALSE)
    nQuality: Word; // Quality Setting, HIGH BYTE should be NOT LOW byte, otherwhise quality=5
      // FUTURE USE, SET TO 0, align strucutre to 331 bytes
    btReserved: array[0..263] of Byte;

  end;

  TAAC = packed record
    dwSampleRate: DWORD;
    byMode: Byte;
    wBitRate: Word;
    byEncodingMethod: Byte;
  end;

  TFormat = packed record
    case Byte of
      1: (mp3: TMP3);
      2: (lhv1: TLHV1);
      3: (aac: TAAC);
  end;

  TBE_Config = packed record
    dwConfig: longword;
    Format: TFormat;
  end;

  PBE_Config = ^TBE_Config;

  TBE_Version = record
    byDLLMajorVersion: Byte;
    byDLLMinorVersion: Byte;
    byMajorVersion: Byte;
    byMinorVersion: Byte;
    byDay: Byte;
    byMonth: Byte;
    wYear: Word;
    zHomePage: array[0..BE_MAX_HOMEPAGE + 1] of Char;
  end;
  PBE_Version = ^TBE_Version;

type
  TbeInitStream = function(var pbeConfig: TBE_CONFIG; var dwSample: longword; var dwBufferSize: longword; var phbeStream: THBE_STREAM): BE_Err; cdecl;
  TbeEncodeChunk = function(hbeStream: THBE_STREAM; nSamples: longword; var pSample; var pOutput; var pdwOutput: longword): BE_Err; cdecl;
  TbeCloseStream = function(hbeStream: THBE_STREAM): BE_Err; cdecl;

  Tbuffer = array[0..bufsize - 1] of Smallint;
  TData16 = array[0..Freq - 1] of Smallint;
  PData16 = ^TData16;
  TMP3RecorderMode = (mprStop, mprRec);

var
  Temp576BufferPos                      : integer;

  beInitStream                          : TbeInitStream;
  beEncodeChunk                         : TbeEncodeChunk;
  beCloseStream                         : TbeCloseStream;

  LAMEENCDLL                            : HWND;

procedure waveInProc(hwi: HWAVEIN; uMsg: UINT; dwInstance: DWORD; dwParam1: DWORD; dwParam2: DWORD); stdcall;
procedure StopRecorder;
procedure SwapRecorderStatus;
procedure OpenTempMP3File;
procedure CloseTempMP3File;
procedure StartRecorder;
procedure CheckMMError(ErrorCode: Cardinal);
procedure mp3recSetProgressBarPosition(NewPosition: integer);

{ WHAT THE WINDOW READS, published as plain integers.

  waveInProc runs on the MULTIMEDIA CALLBACK THREAD and used to write the
  elapsed time and the peak level straight into the dialog's controls, once per
  captured buffer.  SetDlgItemText and SendMessage are kernel calls that Windows
  marshals, so it worked by accident; an LCL control assignment would not, and a
  QueueAsyncCall per buffer would post work many times a second whether or not
  anything changed.  The form polls these on a 100 ms timer instead.

  Integers, deliberately: an aligned 32-bit read or write is atomic on i386, so
  a value that is only ever DISPLAYED needs no lock.  A string would. }
function MP3RecorderElapsedMS: cardinal;
function MP3RecorderPeakLevel: integer;
function MP3RecorderIsRecording: boolean;

{ What WM_INITDIALOG and WM_NCDESTROY did beyond building and destroying
  controls -- loading and freeing lame_enc.dll, and stopping the recorder. }
procedure MP3RecorderWindowOpened;
procedure MP3RecorderWindowClosed;

function InitStrem: boolean;
function SaveLastQSOToMP3File(CE: ContestExchangePtr): boolean;
function MakeMP3Filename(CE: ContestExchangePtr): PAnsiChar;

var
//  TotalBytesInWAVFile              : integer;

  mp3recProgressBarPosition             : integer;

  ID3TAG                                : TID3Rec;

  beConfig                              : TBE_Config { =
    (
    dwConfig: BE_CONFIG_LAME;
    Format:
    (LHV1:
    (dwStructVersion: 1;
    dwStructSize: SizeOf(TBE_Config);
    dwReSampleRate: 0;
    nMode: BE_MP3_MODE_MONO;
    nPreset: Cardinal(LQP_NOPRESET); //LQP_NORMAL_QUALITY;
    dwMpegVersion: MPEG1; //MPEG25;
    bOriginal: True
//    bEnableVBR: True
    )
    )
    )};

  RecorderBitrate                       : Cardinal = 16;
//  RecorderSampleRate               : integer = Freq;
  RecorderDuration                      : TMP3RecorderDuration {= rdEachQSO};

  hLame                                 : THBE_STREAM;

  pMP3OutputBuffer                      : array[0..8640 - 1] of AnsiChar;

  MP3InputBufferIndex                   : Cardinal;

  TempMP3FileHandle                     : HWND;

  dwWrite                               : Cardinal;
  ToWrite                               : Cardinal;

  RecorderStartTime                     : Cardinal;
  dwSamples                             : Cardinal;
  dwMP3Buffer                           : Cardinal;

  BufHead1                              : TWaveHdr;
  BufHead2                              : TWaveHdr;

  Header                                : TWaveFormatEx;

  Address                               : pWaveHdr;

  { Written by the waveIn callback thread, read by the window's timer.  See the
    note on MP3RecorderElapsedMS. }
  gElapsedMS                            : cardinal = 0;
  gPeakLevel                            : integer = 0;
{
  TempWavHeader                    : WavHeader =
    (
    Marker1: ('R', 'I', 'F', 'F');
    Marker2: ('W', 'A', 'V', 'E');
    Marker3: ('f', 'm', 't', ' ');
    Fixed1: 16;
    FormatTag: 1;
    Channels: 1;
    SampleRate: Freq;
    BytesPerSecond: Freq * 2;
    BytesPerSample: 2;
    BitsPerSample: 16;
    Marker4: ('d', 'a', 't', 'a');
    )
    ;
}
//  riff                             :
//    array[1..44] of Byte           =
//    (
//    $52, $49, $46, $46, $74, $75, $0D, $00, {} $57, $41, $56, $45, $66, $6D, $74, $20,
//    $10, $00, $00, $00, $01, $00, $01, $00, {} $44, $AC, $00, $00, $88, $58, $01, $00,
//    $02, $00, $10, $00, $64, $61, $74, $61, {} $50, $75, $0D, $00
//    );

  WaveBuffer                            : array[0..1] of Tbuffer; //������� �����-�����
  whead                                 : array[0..1] of twavehdr; //��������� ��� �����-������
  wfx                                   : TWAVEFORMATEX;
  hwi                                   : HWAVEin;
  MP3RecorderMode                       : TMP3RecorderMode;

  //PaintFrame                            : HDC;
const

  OUTPUTFILE                            = 'TEMP.MP3';
implementation

uses
   uConfigValues, uCFG,
  MainUnit;

function InitStrem: boolean;
begin
  beConfig.dwConfig := BE_CONFIG_LAME;
  beConfig.Format.LHV1.dwStructVersion := 1;
  beConfig.Format.LHV1.dwStructSize := SizeOf(TBE_Config);

  beConfig.Format.LHV1.nMode := BE_MP3_MODE_MONO;
  beConfig.Format.LHV1.nPreset := Cardinal(LQP_NOPRESET); //LQP_NORMAL_QUALITY;
  beConfig.Format.LHV1.dwMpegVersion := MPEG1; //MPEG25;

  beConfig.Format.LHV1.dwSampleRate := Freq;
  beConfig.Format.LHV1.dwBitrate := RecorderBitrate;
  Result := BeInitStream(beConfig, dwSamples, dwMP3Buffer, hLame) = BE_ERR_SUCCESSFUL;
//  if pMP3OutputBuffer = nil then GetMem(pMP3OutputBuffer, dwSamplesMP3);
//  if pMP3InputBuffer = nil then GetMem(pMP3InputBuffer, dwSamples * 2);

  OpenTempMP3File;
end;

procedure StartRecorder;
var
  i                                     : Byte;
begin
  if not InitStrem then Exit;

//  WriteFile(TempMP3FileHandle, TempWavHeader, SizeOf(TempWavHeader), dwWrite, nil);

  for i := 0 to 1 do
     begin
     whead[i].lpData := @WaveBuffer[i];
     whead[i].dwBufferLength := bufsize;
     whead[i].dwFlags := 0;
     end;
  wfx.wFormatTag := WAVE_FORMAT_PCM;
  wfx.nChannels := 1;
  wfx.nSamplesPerSec := Freq;
  wfx.wBitsPerSample := 16;
  wfx.nBlockAlign := wfx.nChannels * (wfx.wBitsPerSample shr 3);
  wfx.nAvgBytesPerSec := wfx.nSamplesPerSec * wfx.nBlockAlign;
  wfx.cbSize := 0;

  CheckMMError(waveinopen(@hwi, wave_mapper, @wfx, DWORD(@waveinproc), 0, callback_function));

  for i := 0 to 1 do
     begin
     waveinprepareheader(hwi, @whead[i], SizeOf(whead[i]));
     end;
  for i := 0 to 1 do
     begin
     waveinaddbuffer(hwi, @whead[i], SizeOf(whead[i]));
     end;
  MP3RecorderMode := mprRec;
  CheckMMError(waveinstart(hwi));
//  MP3RecorderUsed := True;
end;

procedure waveInProc;
label
  NextEncode;
var
  i                                     : Byte;
  Done                                  : Cardinal;
  Amplitude, MaxAmplitude               : Smallint {single};
  t                                     : integer;
//  YScale                           : single;
//  data16                           : PData16;
begin
  case uMsg of
    wim_open:
      begin
      end;

    wim_data:

      for i := 0 to 1 do
         begin
         if ((whead[i].dwFlags and WHDR_DONE) = WHDR_DONE) and (MP3RecorderMode = mprRec) then
            begin

            waveinaddbuffer(hwi, @whead[i], SizeOf(whead[i]));

            Done := 0;

            NextEncode:
            beEncodeChunk(hLame, dwSamples, whead[i].lpData[Done], pMP3OutputBuffer[0], toWrite);
            WriteFile(TempMP3FileHandle, pMP3OutputBuffer[0], toWrite, dwWrite, nil);
  //          if toWrite <> dwWrite then sm;
            Done := Done + dwSamples * SizeOf(SHORT);
            if Done + dwSamples * SizeOf(SHORT) < whead[i].dwBytesRecorded then
               begin
               goto NextEncode;
               end;

            if Done < whead[i].dwBytesRecorded then
               begin
               Temp576BufferPos := whead[i].dwBytesRecorded - Done;
               beEncodeChunk(hLame, Temp576BufferPos div 2, whead[i].lpData[Done], pMP3OutputBuffer[0], toWrite);
               if toWrite > 0 then
                  begin
                  WriteFile(TempMP3FileHandle, pMP3OutputBuffer[0], toWrite, dwWrite, nil);
    //              Windows.SetDlgItemInt(tr4whandle, 88, 0, False);
                  end
               else
   //              Windows.SetDlgItemInt(tr4whandle, 88, Temp576BufferPos, False);
               end;

            // PUBLISHED, NOT PAINTED -- this is the multimedia callback thread.
            gElapsedMS := Windows.GetTickCount - RecorderStartTime;
            MaxAmplitude := 0;

            for t := 0 to Freq - 1 do
               begin
               Amplitude := PData16(whead[i].lpData)^[t];
               if Amplitude > MaxAmplitude then
                  begin
                  MaxAmplitude := Amplitude;
                  end;
               end;
            mp3recSetProgressBarPosition(round(MaxAmplitude * (PeakProgressBarMaxValue * 2 / (1 shl 16))));
            //SendDlgItemMessage(MP3RECWNDHND, 103, PBM_SETPOS, round(MaxAmplitude * (PeakProgressBarMaxValue * 2 / (1 shl 16))), 0);

            end;
         end;

    wim_close:
      begin
      end;

  end;
end;

procedure StopRecorder;
var
  i                                     : integer;
begin
{
  SetFilePointer(TempMP3FileHandle, 0, nil, FILE_BEGIN);
  TempWavHeader.BytesFollowing := TotalBytesInWAVFile + 44 - 8;
  TempWavHeader.DataBytes := TotalBytesInWAVFile;
  WriteFile(TempMP3FileHandle, TempWavHeader, SizeOf(TempWavHeader), dwWrite, nil);
  CloseHandle(TempMP3FileHandle);
}
  if MP3RecorderMode = mprStop then Exit;
  CloseTempMP3File;
  MP3RecorderMode := mprStop;
  waveinreset(hwi);
  for i := 0 to 1 do
     begin
     waveinunprepareheader(hwi, @whead[i], SizeOf(whead[i]));
     end;
  waveinclose(hwi);
  gElapsedMS := 0;
  gPeakLevel := 0;
  mp3recProgressBarPosition := 0;
end;

procedure SwapRecorderStatus;
begin
  if MP3RecorderMode = mprRec then
     begin
     StopRecorder;
     end
  else
     begin
     StartRecorder;
     end;
  FrmSetFocus;
end;

procedure OpenTempMP3File;
begin
  { '%.2u', not '%02u' -- space padding here would put 'TEMP_ 9_ 5.MP3' on disk. }

  StrPCopy(TR4W_TEMP_MP3_FILENAME,
           AnsiString(SysUtils.Format('%s\TEMP_%.2u_%.2u.MP3',
                      [Config.MP3Path, UTC.wHour, UTC.wDay])));
  TempMP3FileHandle := CreateFileA(TR4W_TEMP_MP3_FILENAME, GENERIC_WRITE, FILE_SHARE_WRITE, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  RecorderStartTime := Windows.GetTickCount;
end;

procedure CloseTempMP3File;
begin
  CloseHandle(TempMP3FileHandle);
end;

function MakeMP3Filename(CE: ContestExchangePtr): PAnsiChar;
begin
  { Six zero-padded fields, and this name is the QSO's audio on disk -- a space
    where a zero belongs makes it unfindable. '%02u' -> '%.2u'. }

  StrPCopy(TR4W_GET_MP3_FILENAME,
           AnsiString(SysUtils.Format('%s\%u%.2u%.2u_%.2u%.2u%.2u_%sm_%s.MP3',
                      [Config.MP3Path,
                       CE.tSysTime.qtYear + 2000,
                       CE.tSysTime.qtMonth,
                       CE.tSysTime.qtDay,
                       CE.tSysTime.qtHour,
                       CE.tSysTime.qtMinute,
                       CE.tSysTime.qtSecond,
                       BandStringsArrayWithOutSpaces[CE.Band],
                       string(CE.Callsign)])));

  Result := TR4W_GET_MP3_FILENAME;
end;

function SaveLastQSOToMP3File(CE: ContestExchangePtr): boolean;
begin
  Result := False;
  if MP3RecorderMode = mprStop then Exit;
  if tr4w_WindowsArray[tw_MP3RECORDER].WndHandle = 0 then Exit;

  Windows.ZeroMemory(@ID3TAG, SizeOf(ID3TAG));

  ID3TAG.Tag[0] := 'T';
  ID3TAG.Tag[1] := 'A';
  ID3TAG.Tag[2] := 'G';

  TF.Format(ID3TAG.Year, '%u', CE.tSysTime.qtYear + 2000);
  TF.Format(ID3TAG.Artist, 'QSO with %s', @CE.Callsign[1]);

  Windows.lstrcpyA(@ID3TAG.Album, ContestTypeSA[Contest]);
  Windows.lstrcpyA(@ID3TAG.comment, TR4W_CURRENTVERSION);
  Windows.lstrcpyA(@ID3TAG.Title, @MyCall[1]);
  ID3TAG.Genre := $1C;

  SetFilePointer(TempMP3FileHandle, 0, nil, FILE_END);
  sWriteFile(TempMP3FileHandle, ID3TAG, SizeOf(ID3TAG));

  CloseTempMP3File;

  Windows.CopyFileA(TR4W_TEMP_MP3_FILENAME, DeleteSlashes(MakeMP3Filename(CE)), True);
  OpenTempMP3File;
  Result := True;
end;

procedure CheckMMError(ErrorCode: Cardinal);
begin
  if ErrorCode = MMSYSERR_NOERROR then Exit;
  waveInGetErrorTextA(ErrorCode, @wsprintfBuffer, SizeOf(wsprintfBuffer));
  showwarning(wsprintfBuffer);
end;

procedure mp3recSetProgressBarPosition(NewPosition: integer);
begin
  // The 5-step deadband stays: it was there to stop a SendMessage per buffer,
  // and it still stops the published value jittering between timer ticks.
  if Abs(mp3recProgressBarPosition - NewPosition) < 5 then Exit;
  gPeakLevel := NewPosition;
  mp3recProgressBarPosition := NewPosition;
end;

function MP3RecorderElapsedMS: cardinal;
begin
  Result := gElapsedMS;
end;

function MP3RecorderPeakLevel: integer;
begin
  Result := gPeakLevel;
end;

function MP3RecorderIsRecording: boolean;
begin
  Result := MP3RecorderMode = mprRec;
end;

procedure MP3RecorderWindowOpened;
begin
  if LAMEENCDLL = 0 then
     begin
     LAMEENCDLL := LoadLibrary('lame_enc.dll');
     end;

  if LAMEENCDLL <> 0 then
     begin
     @beInitStream  := GetProcAddress(LAMEENCDLL, 'beInitStream');
     @beEncodeChunk := GetProcAddress(LAMEENCDLL, 'beEncodeChunk');
     @beCloseStream := GetProcAddress(LAMEENCDLL, 'beCloseStream');
     end
  else
     begin
     // Issue #997 (asm push/wsprintf/add esp -> StrPCopy + SysUtils.Format)
     uAnsiStr.StrPCopy(TR4W_TEMP_MP3_FILENAME,
       SysUtils.Format('LAME_ENC.DLL: %s ' + TC_LAME_ERROR + ':' + #13#10#13#10' http://www.tr4w.com/files/',
         [SysErrorMessage(GetLastError)]));
     showwarning(TR4W_TEMP_MP3_FILENAME);
     Exit;
     end;

  Windows.CreateDirectoryA(Config.MP3Path, nil);

  if Config.MP3RecorderEnable and (MP3RecorderMode <> mprRec) then
     begin
     SwapRecorderStatus;
     end;
end;

procedure MP3RecorderWindowClosed;
begin
  StopRecorder;
  if LAMEENCDLL <> 0 then
     begin
     FreeLibrary(LAMEENCDLL);
     LAMEENCDLL := 0;
     end;
end;

end.


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
unit LOGDVP;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  TF,
  VC,
  LogK1EA,
utils_text,
utils_file,
{$IFDEF WINDOWS}
  (* THE SWEEP THIS COMMENT DEFERRED IS DONE (2026-09-08). It used to read
    "still raw Win32 throughout -- a SEPARATE sweep", and the file reads WERE
    raw: CreateFileA, ReadFile, CloseHandle, GetLastError. Those are the RTL
    now -- FileOpen/FileCreate, FileRead, FileClose, GetLastOSError.

    WHAT IS LEFT IS AUDIO, AND IT IS GATED AT THE TWO CALLS:
      sndPlaySoundA   plays the .WAV -- the ONE piece of audio TR4W still
                      owes off Windows, now that the CW sidetone is deleted
      timeSetEvent    signals tDVP_Event when the file duration is up, which
                      is why that event cannot become a SyncObjs.TEvent *)
  Windows,
  MMSystem,
{$ENDIF}
  LogRadio,
  LogWind,
  uCTYDAT,
  Tree;

(* VOICE KEYING, AND WHAT IS GATED HERE.

  TWO different things wear the name DVP in this unit and only one of them runs:

   * THE DVP CARD -- an ISA voice card of the DOS era, addressed through a
     shared memory segment.  Every statement that touched it is commented out
     (SetTransmitControl, the {WLI} lines), DVPInit is the only thing that sets
     DVPSetUp, and NOTHING CALLS DVPInit.  So DVPCommand, the record/listen
     paths and the gain controls are unreachable in this build.

   * DVK WAV PLAYBACK -- PlayWAVFile, driven by Config.DVKEnable.  THIS is what
     an operator hears when a function key sends voice, and it rests on exactly
     two multimedia calls: sndPlaySoundA to start the file, and timeSetEvent to
     signal tDVP_Event when its duration is up so the thread can drop PTT.

  THOSE TWO CALLS ARE WHAT IS GATED, together with the MMSystem import -- so
  winmm, which has no counterpart on either target platform, is now a
  conditional dependency of TR4W rather than an unconditional one.

  THE REST OF THIS UNIT IS STILL RAW WIN32 AND IS NOT GATED: CreateFile,
  CloseHandle, ZeroMemory and a thread started by handle.  That is a portable
  rewrite (TFileStream, TThread), not a conditional, and it belongs to the
  cross-platform sweep rather than to this change.  Gating it would only move
  the failure from a compile error to a silent no-op.

  The replacement for the two gated calls is NOT guessed at here: fpsound plays
  a WAV cross-platform but does not report when it FINISHED, which is the whole
  reason the timer exists.  A player that reports completion removes both calls
  at once.  See docs/PLATFORM_CLOCK_ABSTRACTION.md, which measures the same
  winmm dependency for CW element timing and lands in the same place. *)
type
  PlayResult = (prOK, prCantPlay, prExitThread);

const
  MaxDVPMessageLength                   = 20;
  DVPArraySize                          = 30;

var

//  CfgDvpPath                            : Str40 = '';
  Count                                 : integer;
//  DVPPath                               : ShortString;

  PlayWAVThread, PlayWAVThreadID        : Cardinal;
  WAVFileToPlay                         : array[0..255] of AnsiChar;
  DVPMessagesArray                      : array[1..DVPArraySize] of Str40;
  DVPMessagesArrayIndex                 : integer = 1;
  DVPThreadID                           : TThreadID;
  tMissCallsFileEnable                  : boolean;
//  MissedCallsignsListInitialized        : boolean;
//  MissedWAVCallsigns                    : integer = -1;
//  MissedWAVCallsignsListbox             : HWND;
  BackCopyEnable                        : boolean;
  DVPSetUp                              : boolean;
  SBDVPActive                           : boolean;

function DVPActive: boolean;
function DVPMessagePlaying: boolean;

//procedure StartBackCopy;
procedure StopBackCopy;
procedure SaveBackCopy(QSONumber: integer; Seconds: integer);
//procedure SaveBackCopyFile(FileName: Str40; Seconds: integer);
procedure DVPCommand(Command: integer; FileName: Str80; UseDVPPath: boolean);
procedure DVPListenMessage(FileName: Str80; UseDVPPath: boolean);
procedure DVPRecordMessage(FileName: Str80; OnAir: boolean);
procedure DVPInit;
procedure DVPUnInit;
procedure DVPStopPlayback;
procedure SetMicGain(Gain: Byte);
procedure SetOutGain(Gain: Byte);

function tGetWAVDurationFromHeader(FileName: PAnsiChar; var Duration: Cardinal; DisplayError: boolean): boolean;
procedure tDVPPlayThreadproc;
procedure tWriteCallsignToMissingCallsignsFile(Callsign: PAnsiChar);

procedure EnumMISSINGCALLSIGNSTXT(FileString: PShortString);

function tsndPlaySound(lpszSoundName: PAnsiChar): boolean;
function PlayWAVFile(f: PAnsiChar; DisplayError: boolean): PlayResult;

implementation
uses
   uConfigValues,
  MainUnit,
  LogStuff;

{$IFDEF WINDOWS}

const
  DVPGetPtr                             = 0;
  DVPRecRX                              = 2;
  DVPRecMic                             = 3; {SBDVP too}
  DVPPlay                               = 4; {SBDVP too}
  DVPStopPlay                           = 5; {SBDVP too}
  DVPStopRec                            = 6;
  DVPCloseAll                           = 10;
  DVPR2H                                = 11;
  DVPF2H                                = 12;
  DVPM2H                                = 13;
  DVPF2M                                = 14;
  DVPM2M                                = 15;
  DVPR2F                                = 16;
  DVPM2F                                = 17;
  DVPRXEn                               = 18;
  DVPRXDis                              = 19;
  DVPMicEn                              = 20;
  DVPMicDis                             = 21;
  DVPInGain                             = 22;
  DVPOutGain                            = 23;
  DVPMon                                = 24;
  DVPNoMon                              = 25;
  DVPOnAir                              = 26; {SBDVP too}
  DVPOffAir                             = 27; {SBDVP too}
  DVPBackCopy                           = 28;
  DVPNoBackCopy                         = 29;
  DVPSaveBackCopy                       = 30;
  DVPPTT                                = 31;
  DVPNoPTT                              = 32;
  DVPRpt                                = 33;
  DVPNoRpt                              = 34;
  DVPBeep                               = 37;
  DVPQuiet                              = 39;
  DVPDisableHK                          = 40;
  DVPEnableHK                           = 41;
  DVPIsActive                           = 43; {SBDVP too}

  R2H                                   = $1; { RX to HeadSet     }
  F2H                                   = $2; { D/A to Headset    }
  M2H                                   = $4; { Mic In to Headset }
  F2M                                   = $8; { D/A to Mic Out    }
  PTT                                   = $40; { PTT control       }

  { Record control values }

  M2M                                   = $10; { Mic In to Mic Out }
  R2F                                   = $20; { RX to A/D         }
  M2F                                   = $40; { Mic to A/D        }

type
  DVPSharedMemory = record
    FileName: array[1..64] of AnsiChar;
    FileOpen: integer; { + 40h bytes }
    Command: integer; { + 42h bytes }
    Handle: integer; { + 44h bytes }
    RepeatDelay: integer; { + 46h bytes }
    Start: LONGINT; { + 48h bytes }
    length: LONGINT; { + 4Ch bytes }
    InputGain: Byte; { + 50h bytes }
    OutputGain: Byte; { + 51h bytes }
    XmitControl: Byte; { + 52h bytes }
    RecControl: Byte; { + 53h bytes }
  end;

  SharedMemoryPointer = ^DVPSharedMemory;

//var
 // SharedMemorySegment, SharedMemoryOffset: Word;
//  SharedMemory                          : SharedMemoryPointer;

function DVPActive: boolean;
begin
   (* THIS BODY WAS EMPTY -- in this tree AND in the D7 source it was copied
     from -- so the result was whatever the register happened to hold, at six
     call sites that gate voice keying on it.  Two of those bodies are empty,
     but the other four spin waiting for playback or call DVPStopPlayback.

     False is the TRUE answer, not a safe default: DVPSetUp is set only by
     DVPInit, and nothing calls DVPInit.  There is no DVP card in this build to
     be active. *)
   Result := False;
end;

procedure SetTransmitControl(Bytes: Byte);

begin
  //{WLI}    Mem [SharedMemorySegment : SharedMemoryOffset + $52] := Bytes;
end;

procedure SetRecordControl(Bytes: Byte);

begin
  //{WLI}    Mem [SharedMemorySegment : SharedMemoryOffset + $53] := Bytes;
end;

procedure DVPCommand(Command: integer; FileName: Str80; UseDVPPath: boolean);

begin

end;

procedure SetMicGain(Gain: Byte);

begin
  //    Mem [SharedMemorySegment : SharedMemoryOffset + $50] := Gain;
end;

procedure SetOutGain(Gain: Byte);

begin
  //    Mem [SharedMemorySegment : SharedMemoryOffset + $51] := Gain;
end;

procedure TypicalDVPStartUp;

begin
  DVPCommand(DVPDisableHK, '', False);
  Sleep(10);
  DVPCommand(DVPMicEn, '', False);
  Sleep(10);
  DVPCommand(DVPRXEn, '', False);
  Sleep(10);
  DVPCommand(DVPR2H, '', False);
  Sleep(10);
  DVPCommand(DVPM2M, '', False);
  Sleep(10);
  DVPCommand(DVPPTT, '', False);
  Sleep(10);
  DVPCommand(DVPOnAir, '', False);
  Sleep(10);

  SetMicGain(8);
  DVPCommand(DVPInGain, '', False);
  Sleep(10);

  SetOutGain(8);
  DVPCommand(DVPOutGain, '', False);
  Sleep(10);
end;

procedure DVPRecordMessage(FileName: Str80; OnAir: boolean);

begin
  {    IF NOT DVPSetUp THEN Exit;

      SetLength (MaxDVPMessageLength);

      IF OnAir THEN
          BEGIN
          SetRecordControl (M2F OR F2M OR PTT);
          SetTransmitControl (M2M OR PTT);
          DVPCommand (DVPOnAir, FileName, True);
          END
      ELSE
          BEGIN
          SetRecordControl (M2F);
          SetTransmitControl (M2H);
          END;

      DVPCommand (DVPRecMic, FileName, True);
      REPEAT UNTIL KeyPressed;
      IF ReadKey = NullKey THEN ReadKey;
      DVPCommand (DVPStopRec, '', True);
      DVPCommand (DVPCloseAll, '', True);
      DVPCommand (DVPOffAir, FileName, True);
     }
end;

procedure DVPListenMessage(FileName: Str80; UseDVPPath: boolean);

begin
  if not DVPSetUp then Exit;
  SetTransmitControl(F2H);
  DVPCommand(DVPPlay, FileName, UseDVPPath);
end;

procedure DVPStopPlayback;

begin
  if not ((DVPSetUp) and (DVPMessagePlaying)) then Exit;

  DVPCommand(DVPStopPlay, '', False);
end;

procedure DVPUnInit;

begin


end;

procedure DVPInit;

begin

  DVPSetUp := True;

end;


procedure StopBackCopy;

begin
  if not DVPSetUp then Exit;
  DVPCommand(DVPNoBackCopy, 'BACKCOPY.WAV', True);
end;

procedure SaveBackCopy(QSONumber: integer; Seconds: integer);

{var
  TempString, FileName                  : Str20;
}
begin
  {    IF NOT DVPSetUp THEN Exit;
      SetLength (Seconds);

      Str (QSONumber, Filename);

      WHILE FileExists (FileName + '.BCP') DO
          BEGIN
          IF Copy (FileName, Length (FileName), 1) >= 'A' THEN
              BEGIN
              TempString := Copy (FileName, Length (FileName), 1);
              Delete (FileName, Length (FileName), 1);

              TempString [1] := Chr (Ord (TempString [1]) + 1);
              FileName := FileName + TempString;
              END
          ELSE
              FileName := FileName + 'A';
          END;

      DVPCommand (DVPSaveBackCopy, FileName + '.BCP', False);
      SetLength (20);
     }
end;
{
procedure SaveBackCopyFile(FileName: Str40; Seconds: integer);

begin
  if not DVPSetUp then Exit;
  SetLength(Seconds);
  DVPCommand(DVPSaveBackCopy, FileName, False);
  SetLength(20);
end;
}

function DVPMessagePlaying: boolean;

begin
  DVPMessagePlaying := False;
  {
         IF NOT DVPSetUp THEN Exit;
         DVPCommand (DVPIsActive, FileName, False);
         DVPMessagePlaying := (Mem [SharedMemorySegment : SharedMemoryOffset + $42] AND 1) = 1;
  }
end;

function tGetWAVDurationFromHeader(FileName: PAnsiChar; var Duration: Cardinal; DisplayError: boolean): boolean;
label
  1;
var
  Head                                  : WavHeader;
  r                                     : REAL;
  h                                     : THandle;   (* A FILE handle, not a window. *)
  (* SIGNED, because FileRead RETURNS -1 on error where Windows.ReadFile
    reported failure separately. As a Cardinal that becomes 4294967295, which
    is > 0 and equal to no size -- so an error would have read as a large
    successful read. Same trap logwind had. *)
  lpNumberOfBytesRead                   : Integer;
begin
  Result := False;
{
  asm
    push FileName
    lea  eax,TR4W_PATH_NAME
    push eax
  end;
  wsprintf(WAVFileToPlay, TWO_STRINGS);
  asm add esp,16
  end;
}
  if TF.tOpenFileForRead(h, FileName {WAVFileToPlay}) then
     begin
     (* FileRead RETURNS the count, where Windows.ReadFile delivered it
       through a var parameter and reported failure as a separate boolean.
       -1 is its error, so the test is "did we get a whole header" -- which is
       what the old code checked anyway, one step later. *)
     lpNumberOfBytesRead := FileRead(h, Head, SizeOf(WavHeader));
     if lpNumberOfBytesRead = SizeOf(WavHeader) then
        begin
        Result := True;
        r := int64(1000) * Head.BytesFollowing div Head.SampleRate div Head.BytesPerSample;
        Duration := Trunc(r) + 100;
        FileClose(h);
        Exit;
        end;
     FileClose(h);
     end;
  1:
  if DisplayError then
     begin
     QuickDisplay(SysUtils.Format('%s : %s',
                  [string(FileName), SysUtils.SysErrorMessage(GetLastOSError)]));
     end;
end;

procedure tDVPPlayThreadproc;
label
  ExitLabel, PlayNextMessage, NextMessage;
var
  Index                                 : integer;
  i                                     : integer;
  WAVFile                               : array[0..255] of AnsiChar;
  //Duration                              : Cardinal;
  TempChar                              : AnsiChar;
  Pauselenght                           : Cardinal;
  p                                     : PAnsiChar;
  TempPlayResult                        : PlayResult;
const
  DOTWAVASINTEGER                       = 1447122734;
begin
  Index := 1;

  PlayNextMessage:
  if DVPMessagesArray[Index][1] = '*' then
     begin
     Pauselenght := 0;
     for i := 1 to length(DVPMessagesArray[Index]) do
       if DVPMessagesArray[Index][i] = '*' then
          begin
          Pauselenght := Pauselenght + 20
          end
       else
          begin
          goto NextMessage;
          end;
     Sleep(Pauselenght);
     goto NextMessage;
     end;

  p := @DVPMessagesArray[Index][1];

     {Some WAV File}
  if StringHas(DVPMessagesArray[Index], '.WAV') then
     begin
     {
    asm
    push p
    lea  eax,TR4W_DVPPATH
    push eax
    end;
    wsprintf(WAVFile, '%s\%s');
    asm add esp,16
    end;
}
         if PlayWAVFile(p, True) = prExitThread then
            begin
            goto ExitLabel;
            end;
         goto NextMessage;
     end;

  if Config.UseRecordedSigns then
     begin
     //QSO Number
   if StringIsAllNumbers(DVPMessagesArray[Index]) then
      begin

      StrPCopy(WAVFile, AnsiString(SysUtils.Format('FULLSERIALNUMBERS\%s.WAV', [string(DVPMessagesArray[Index])])));

      TempPlayResult := PlayWAVFile(WAVFile, False);
      if TempPlayResult = prExitThread then
         begin
         goto ExitLabel;
         end;

      if TempPlayResult = prCantPlay then
         begin
         for i := 1 to length(DVPMessagesArray[Index]) do
            begin
            TempChar := DVPMessagesArray[Index][i];
            // Issue #997: asm wsprintf-push -> TF.Format. %C -> %c (Char overload);
            // TempChar is an ASCII letter/digit/'_', so %c output == the old %C.
            StrPCopy(WAVFile, AnsiString(SysUtils.Format('LETTERSANDNUMBERS\%s.WAV', [string(TempChar)])));
            if PlayWAVFile(WAVFile, True) = prExitThread then
               begin
               goto ExitLabel;
               end;
            end;
         end;

      goto NextMessage;
      end;

     //Callsign

   StrPCopy(WAVFile, AnsiString(SysUtils.Format('FULLCALLSIGNS\%s.WAV', [string(DVPMessagesArray[Index])])));

   TempPlayResult := PlayWAVFile(WAVFile, False);
   if TempPlayResult = prExitThread then
      begin
      goto ExitLabel;
      end;

   if TempPlayResult = prCantPlay then
      begin
      tWriteCallsignToMissingCallsignsFile(p);
      for i := 1 to length(DVPMessagesArray[Index]) do
         begin
         TempChar := DVPMessagesArray[Index][i];
         if TempChar = '/' then
            begin
            TempChar := '_';
            end;
         // Issue #997: asm wsprintf-push -> TF.Format. %C -> %c (Char overload).
         StrPCopy(WAVFile, AnsiString(SysUtils.Format('LETTERSANDNUMBERS\%s.WAV', [string(TempChar)])));
         if PlayWAVFile(WAVFile, True) = prExitThread then
            begin
            goto ExitLabel;
            end;
         end;
      end;

     end
  else
     begin
     Sleep(0);
     end;

//  asm nop end;

  NextMessage:
  inc(Index);
  if Index = DVPMessagesArrayIndex then goto ExitLabel else goto PlayNextMessage;

  ExitLabel:
  DVPMessagesArrayIndex := 1;
  PTTOff;

  tStartAutoCQ;

  tExitFromDVPThread := False;
  DVPOn := False;
  ClearThread(DVPThreadID);
  DisplayCodeSpeed;
  FillChar(DVPMessagesArray, SizeOf(DVPMessagesArray), 0);
  BackToInactiveRadioAfterQSO;
end;

procedure EnumMISSINGCALLSIGNSTXT(FileString: PShortString);
begin
//  tLB_ADDSTRING(MissedWAVCallsignsListbox, @FileString^[1]);
//  MissedCallsignsList.AddString(FileString^, NoBand, NoMode, True);
//  inc(MissedWAVCallsigns);
end;

procedure tWriteCallsignToMissingCallsignsFile(Callsign: PAnsiChar);
label
  1, CallsignFound, NextRead;
var
  TempBuffer                            : array[0..1024 - 1] of AnsiChar;
  h                                     : THandle;   (* A FILE handle, not a window. *)
  (* SIGNED, because FileRead RETURNS -1 on error where Windows.ReadFile
    reported failure separately. As a Cardinal that becomes 4294967295, which
    is > 0 and equal to no size -- so an error would have read as a large
    successful read. Same trap logwind had. *)
  lpNumberOfBytesRead                   : Integer;
  p                                     : PAnsiChar;
begin
  if not tMissCallsFileEnable then Exit;
  if not LooksLikeACallSign(Callsign) then Exit;
  p := GetRealPath(Config.DVKPath, 'FULLCALLSIGNS\MISSINGCALLSIGNS.TXT', nil);
  (* FileOpen/FileCreate, not CreateFileA. OPEN_ALWAYS means "open it, and
    create it if it is not there", which the RTL splits into two calls. *)
  (* p is a PAnsiChar and the FileExists in scope here takes one (TF s), so it
    is passed straight through; the RTL open/create take a string, and
    AnsiString is the narrow one -- string() would widen to UnicodeString and
    then narrow back, which the ratchet counts. *)
  if FileExists(p) then
     begin
     h := FileOpen(AnsiString(p), fmOpenReadWrite or fmShareDenyNone);
     end
  else
     begin
     h := FileCreate(AnsiString(p));
     end;
  if h = feInvalidHandle then
     begin
     //    ShowSysErrorMessage(p);
         Exit;
     end;

  NextRead:
  FillChar(TempBuffer, SizeOf(TempBuffer), 0);
  lpNumberOfBytesRead := FileRead(h, TempBuffer, SizeOf(TempBuffer));
  if lpNumberOfBytesRead > 0 then
     begin
     if strpos(TempBuffer, Callsign) <> nil then
        begin
        goto CallsignFound;
        end;
     if lpNumberOfBytesRead = SizeOf(TempBuffer) then
        begin
        goto NextRead;
        end;
     end;

  swriteFile(h, Callsign^, lstrlenA(Callsign));
  swriteFile(h, #13#10, 2);

  CallsignFound:
  FileClose(h);
end;

function tsndPlaySound(lpszSoundName: PAnsiChar): boolean;
begin
  Result := False;
{
  asm
    push lpszSoundName
    lea  eax,TR4W_PATH_NAME
    push eax
  end;
  wsprintf(WAVFileToPlay, TWO_STRINGS);
  asm add esp,16
  end;
}
  if not FileExists(lpszSoundName {WAVFileToPlay}) then Exit;
  if ActiveRadioPtr.tPTTStatus = PTT_OFF then
     begin
     PTTOn;
     end;
{$IFDEF WINDOWS}
  Result := sndPlaySoundA(lpszSoundName {WAVFileToPlay}, SND_ASYNC or SND_NODEFAULT);
{$ELSE}
  (* THE VOICE KEYER HAS NO PLAYER OFF WINDOWS YET, and this is the ONE piece
    of audio TR4W still owes there -- the CW sidetone was deleted on
    2026-09-08, so this is what is left of the question.

    IT IS A MUCH EASIER PROBLEM THAN THE SIDETONE WAS: a .WAV file played
    whole, with about half a second of tolerance, rather than a tone that has
    to start and stop with a CW element. Any of the usual answers would do.

    Returning False is what the caller already handles -- it is the same
    result as a missing or unreadable file -- so the DVP simply reports that
    it could not play rather than behaving as though it had. *)
  Result := False;
  if logger <> nil then
     begin
     logger.Info('[DVP] cannot play %s: no audio backend on this platform',
                 [string(lpszSoundName)]);
     end;
{$ENDIF}
end;

function PlayWAVFile(f: PAnsiChar; DisplayError: boolean): PlayResult;
var
  Duration                              : Cardinal;
  WAVFile                               : PAnsiChar;
  countrtyId                            : DXMultiplierString;
  //tempBuffer                            : array[0..255 + 64] of Char;
begin
  Result := prCantPlay;

  WAVFile := nil;

  if Config.DVKLocalizedMessagesEnable then
    if CallWindowString <> '' then
       begin
       FillChar(countrtyId, SizeOf(countrtyId), 0);
       countrtyId := ctyGetCountryID(CallWindowString);
       if (countrtyId <> '') then
          begin
          if (countrtyId[1] = 'U') and (countrtyId[2] = 'A') then
             begin
             countrtyId[3] := #0;
             end;

          WAVFile := GetRealPath(Config.DVKPath, f, @countrtyId[1]);
        //ShowMessage(WAVFile);
          if not FileExists(WAVFile) then
             begin
             WAVFile := nil;
             end;
          end;
       end;

  if WAVFile = nil then
     begin
     WAVFile := GetRealPath(Config.DVKPath, f, nil);
     end;

  if tGetWAVDurationFromHeader(WAVFile, Duration, DisplayError) then
     begin
     if tsndPlaySound(WAVFile) = False then
        begin
        if DisplayError then
           begin
           QuickDisplay(SysErrorMessage(GetLastOSError));
           end;
        end
     else
        begin
        (* winmm signals tDVP_Event when the file's own duration is up, and the
          wait is what holds PTT down for exactly as long as the audio lasts.
          The two halves must be replaced together. *)
{$IFDEF WINDOWS}
        tDVPTimerEventID := timeSetEvent(Duration, 0, TFNTimeCallBack(tDVP_Event), 0, TIME_CALLBACK_EVENT_SET);
        WaitForSingleObject(tDVP_Event, 30000);
{$ELSE}
        (* GATED WITH THE PLAYBACK IT WAITS FOR. This is winmm signalling
          tDVP_Event when the file's duration is up -- the multimedia timer
          writes the Win32 HANDLE itself, which is why tDVP_Event cannot
          become a SyncObjs.TEvent the way tNet_Event did.

          Nothing was started above (tsndPlaySound returned False), so there
          is nothing to wait for and the caller drops PTT immediately. *)
{$ENDIF}
        if tExitFromDVPThread then Result := prExitThread else Result := prOK;
        end;
     end;
end;

{$ELSE}

(* ===================================================================
   NO VOICE KEYER OFF WINDOWS -- AND IT SAYS SO ON THE SCREEN.

   Everything above is Win32: the multimedia calls, but also the file reads
   (Windows.ReadFile / CloseHandle), the buffer clears and the playback
   thread.  Gating the whole implementation rather than each call keeps the
   Windows path byte-for-byte unchanged and puts ONE boundary here instead of
   a dozen scattered ones.

   THE POINT OF THIS BLOCK IS THE QuickDisplay (NY4I, 2026-09-07).  A stub
   that quietly does nothing is the failure this tree keeps paying for: an
   operator hits a function key, no audio comes out, nothing is written
   anywhere, and the bug report is "voice doesn't work".  Every routine an
   operator can REACH says why instead.  The internal ones stay silent --
   they are called from the ones that already spoke.

   The port is small and is described at the top of this unit: it is
   sndPlaySoundA and timeSetEvent, plus a portable rewrite of the file reads.
   NOTE that it cannot be checked by tools/Compile-Linux.ps1 yet -- LOGDVP's
   uses clause reaches MainUnit and LogWind, which are not portable -- so
   this gate is reviewed by eye, not proven by a compiler.  That is a weaker
   guarantee than the gates in ComPortEnumerator and uYCCCSO2R, and it is
   stated rather than glossed.
   =================================================================== *)

resourcestring
   SDVPNotOnThisPlatform =
      'Voice keying is Windows-only in this build -- no audio was sent.';
   SDVPRecordNotOnThisPlatform =
      'Voice recording is Windows-only in this build.';

procedure ReportNoVoiceKeyer;
begin
   QuickDisplay(SDVPNotOnThisPlatform);
end;

function DVPActive: boolean;
begin
   (* Same answer as on Windows, and for the same reason: nothing calls
     DVPInit, so there is no DVP card to be active.  Callers branch on this
     before they reach anything below, which is why most of these stubs are
     never entered. *)
   Result := False;
end;

function DVPMessagePlaying: boolean;
begin
   Result := False;
end;

procedure StopBackCopy;
begin
end;

procedure SaveBackCopy(QSONumber: integer; Seconds: integer);
begin
end;

procedure DVPCommand(Command: integer; FileName: Str80; UseDVPPath: boolean);
begin
   ReportNoVoiceKeyer;
end;

procedure DVPListenMessage(FileName: Str80; UseDVPPath: boolean);
begin
   ReportNoVoiceKeyer;
end;

procedure DVPRecordMessage(FileName: Str80; OnAir: boolean);
begin
   QuickDisplay(SDVPRecordNotOnThisPlatform);
end;

procedure DVPInit;
begin
end;

procedure DVPUnInit;
begin
end;

procedure DVPStopPlayback;
begin
   (* Silent on purpose: stopping something that never started is not a
     failure the operator needs told about, and this is called on every
     keystroke that interrupts sending. *)
end;

procedure SetMicGain(Gain: Byte);
begin
end;

procedure SetOutGain(Gain: Byte);
begin
end;

function tGetWAVDurationFromHeader(FileName: PAnsiChar; var Duration: Cardinal;
                                   DisplayError: boolean): boolean;
begin
   Duration := 0;
   Result := False;
end;

procedure tDVPPlayThreadproc;
begin
end;

procedure tWriteCallsignToMissingCallsignsFile(Callsign: PAnsiChar);
begin
end;

procedure EnumMISSINGCALLSIGNSTXT(FileString: PShortString);
begin
end;

function tsndPlaySound(lpszSoundName: PAnsiChar): boolean;
begin
   (* Internal -- PlayWAVFile is the caller and it reports for both. *)
   Result := False;
end;

function PlayWAVFile(f: PAnsiChar; DisplayError: boolean): PlayResult;
begin
   (* THE LIVE PATH.  This is what a function key configured with a .WAV
     reaches, so this is the one that must not fail in silence.  It reports
     regardless of DisplayError: that flag distinguishes a missing FILE from a
     working one, and this is neither. *)
   ReportNoVoiceKeyer;
   Result := prCantPlay;
end;

{$ENDIF}

end.

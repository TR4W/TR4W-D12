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
unit uSynTime;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses
  VC,
  TF,
//  tr4wutils,
  (* Windows is gone (2026-09-08): GetSystemTime for T1/T4 and
    FileTimeToSystemTime for the NTP reply both go through TDateTime now --
    see SystemTimeFromDateTime. *)
  DateUtils,
  Tree,
  uNet,
  IdUDPClient,    { the NTP query -- Indy, not WinSock }
  IdGlobal,       { TIdBytes }
  Forms,          { Application.QueueAsyncCall -- the warning is main-thread work }
  Dialogs,        { MessageDlg }
  SysUtils,
  (* Registry is WINDOWS-ONLY HERE, and gated with the one function that uses
    it. FPC's fcl-registry does provide a Registry unit off Windows -- it
    stores an XML file under the user's home -- but that is emphatically NOT
    what this code wants: it reads the W32Time SERVICE's configuration out of
    HKLM, which is a Windows service that does not exist elsewhere and whose
    key an XML shim would never contain. Linking it would compile and then
    read nothing, forever, in silence. *)
{$IFDEF WINDOWS}
  Registry,
{$ENDIF}
  uTR4WStrings;

procedure GetInt64AndSysTimeFromBuffer(BufPtr: Byte; var St: SYSTEMTIME);

procedure CheckNTPAtStartup;


// the Synchronize PC Time dialog.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.

implementation
uses
  MainUnit,
  uTelnet;

var
//  ST_saddr                              : sockaddr_in = (sin_family: AF_INET; sin_port: 31488);
  ST_Buffer                             : array[1..48] of Byte;
  Offset                                : int64;
  NTPStartupThreadID                    : TThreadID;
const
  NTP_SERVER                            = 'pool.ntp.org';




(* A TDateTime INTO VC's SYSTEMTIME.

  SysUtils.DateTimeToSystemTime exists and CANNOT be used here: its
  TSystemTime orders the fields Year, Month, Day, DayOfWeek where Win32 -- and
  therefore VC's SYSTEMTIME, which is on the wire between stations -- orders
  them wYear, wMonth, wDayOfWeek, wDay. Substituting it would silently swap the
  day and the day-of-week. VC's own declaration says so at length; this is that
  warning applied.

  wDayOfWeek is filled because the Win32 calls this replaces filled it. Win32
  numbers from 0 = Sunday, SysUtils.DayOfWeek from 1. *)
procedure SystemTimeFromDateTime(const aWhen: TDateTime; var St: SYSTEMTIME);
begin
   DecodeDateTime(aWhen, St.wYear, St.wMonth, St.wDay,
                  St.wHour, St.wMinute, St.wSecond, St.wMilliseconds);
   St.wDayOfWeek := DayOfWeek(aWhen) - 1;
end;

procedure GetInt64AndSysTimeFromBuffer(BufPtr: Byte; var St: SYSTEMTIME);
const
  t                                     = {4311810304;} $0101010101;
var
  dt                                    : TDateTime;
  t64                                   : int64;
  Sec                                   : int64;
  msec                                  : int64;
begin

  Sec := int64(ST_Buffer[BufPtr + 3])
    + int64(ST_Buffer[BufPtr + 2]) * 256
    + int64(ST_Buffer[BufPtr + 1]) * 256 * 256
    + int64(ST_Buffer[BufPtr]) * 256 * 256 * 256;

  msec :=
    int64(ST_Buffer[BufPtr + 7]) +
    int64(ST_Buffer[BufPtr + 6]) * 256 +
    int64(ST_Buffer[BufPtr + 5]) * 256 * 256 +
    int64(ST_Buffer[BufPtr + 4]) * 256 * 256 * 256;

  msec := round((msec / t) * 1000);

  { t64 is 100-nanosecond units since 1601-01-01 -- the FILETIME epoch. The
    9435484800 is the seconds between 1601-01-01 and 1900-01-01, which is where
    the NTP timestamp above starts. }
  t64 := (msec + Sec * 1000) * 10000 + 9435484800 * 10000000;

  (* THE SAME ARITHMETIC, WITHOUT THE WINDOWS CALL. Was
    FILETIME(t64) + Windows.FileTimeToSystemTime.

    864000000000 is the number of 100ns units in a day, and 109205 is the days
    from the FILETIME epoch (1601-01-01) to the TDateTime epoch (1899-12-30).
    That constant is not folklore: FILETIME for 1970-01-01 is
    116444736000000000, which divided by 864000000000 is 134774, and
    134774 - 109205 = 25569 -- the TDateTime for 1970-01-01. Checked both ways
    before it was written down.

    wDayOfWeek is filled because FileTimeToSystemTime filled it, and a caller
    reading it would otherwise get a stale zero. Win32 numbers from 0 = Sunday
    and SysUtils.DayOfWeek from 1. *)
  dt := (t64 / 864000000000.0) - 109205.0;
  SystemTimeFromDateTime(dt, St);

end;


(* Returns the NTP server configured for Windows W32Time (from the registry),
  falling back to pool.ntp.org if not set.

  OFF WINDOWS THE REGISTRY HALF IS SKIPPED AND THE FALLBACK AT THE BOTTOM DOES
  THE WORK -- Result stays '', so `if Result = '' then Result := NTP_SERVER`
  hands back pool.ntp.org. That is already the behaviour on any Windows machine
  where W32Time has no NtpServer value, so this is an existing, exercised path
  rather than a new one.

  WHAT IS NOT DONE, and is a real gap rather than an oversight: macOS and Linux
  DO have a configured time server, and it is not read. macOS answers
  `systemsetup -getnetworktimeserver`; Linux keeps it in
  /etc/systemd/timesyncd.conf or /etc/ntp.conf depending on the daemon. Each is
  a different mechanism, none of them a registry, so this wants a small
  per-platform reader rather than a translation of the code below. Until then
  an operator whose station syncs to a local NTP box gets pool.ntp.org, which
  works but is not what they configured. *)
function GetWindowsNTPServer: string;
var
{$IFDEF WINDOWS}
   reg: TRegistry;
{$ENDIF}
   spacePos: integer;
   commaPos: integer;
begin
   Result := '';
{$IFDEF WINDOWS}
   reg := TRegistry.Create(KEY_READ);
   try
      reg.RootKey := HKEY_LOCAL_MACHINE;
      if reg.OpenKeyReadOnly('SYSTEM\CurrentControlSet\Services\W32Time\Parameters') then
         begin
         if reg.ValueExists('NtpServer') then
            begin
            Result := reg.ReadString('NtpServer');
            end;
         reg.CloseKey;
         end;
   finally
      reg.Free;
   end;
{$ENDIF}
   // Multiple servers are space-separated; take the first
   spacePos := Pos(' ', Result);
   if spacePos > 0 then
      begin
      Result := Copy(Result, 1, spacePos - 1);
      end;
   // Strip flags suffix e.g. "time.windows.com,0x9" -> "time.windows.com"
   commaPos := Pos(',', Result);
   if commaPos > 0 then
      begin
      Result := Copy(Result, 1, commaPos - 1);
      end;
   if Result = '' then
      begin
      Result := NTP_SERVER;
      end;
end;

{ THE WARNING, ON THE MAIN THREAD.

  THIS IS A CORRECTNESS FIX, NOT A STYLE ONE.  NTPStartupCheck runs on a worker
  thread (tCreateThread, see CheckNTPAtStartup), and the MessageBoxW this
  replaces was called from there.  Win32 tolerates that; THE LCL DOES NOT --
  showing a form from a non-main thread is undefined, and this one is a modal
  dialog raised while the main window is still starting up.

  Application.QueueAsyncCall and not TThread.Queue, for the reason uPanelUpdate
  and uNet both record: TThread.Queue purges by the calling thread's id when
  that thread dies, and this thread's whole job finishes the moment it has
  asked for the warning. }
type
   TClockWarning = class
      Text: string;
      procedure Show(Data: PtrInt);
   end;

procedure TClockWarning.Show(Data: PtrInt);
begin
   try
      MessageDlg(TC_TR4WTIMEWARNING, Text, mtWarning, [mbOK], 0);
   finally
      Free;   { queued once, shown once, gone }
   end;
end;

procedure WarnAboutClockOffset(const aSeconds: int64; const aServer: string);
var
   w: TClockWarning;
begin
   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;

   w := TClockWarning.Create;
   w.Text := Format('Warning: PC clock is %d seconds off from NTP server (%s).'
                    + sLineBreak + sLineBreak
                    + 'Please synchronize your Windows time.',
                    [aSeconds, aServer]);
   Application.QueueAsyncCall(w.Show, 0);
end;

{ THE STARTUP CLOCK CHECK.  Reads the offset against an NTP server and WARNS;
  it has never set the clock, and that is why it survived the removal of the
  Synchronize-PC-time dialog on 2026-08-25 -- setting needs UAC elevation, and
  checking does not.

  INDY, NOT WINSOCK.  This was raw WinSock2 -- GetConnection, setsockopt,
  Send, recv, closesocket -- which is the same transport the DX cluster and the
  multi-op link already left behind.  TIdUDPClient carries its own receive
  timeout, closes itself, and is the one socket API this program still keeps.

  WHAT IS DELIBERATELY STILL WIN32, so the next reader does not "finish the
  job" and break it:

    Windows.GetSystemTime for T1/T4.  These feed STToInt64 alongside the two
    SERVER timestamps decoded from the packet, and the whole offset is computed
    in that one representation.  SysUtils.TSystemTime and Windows.SYSTEMTIME
    are SEPARATE DECLARATIONS that merely happen to share a layout
    (docs/PLATFORM_CLOCK_ABSTRACTION.md), so substituting one for the other is
    exactly the swap that compiles and quietly changes meaning.  Moving this to
    TDateTime means moving the epoch arithmetic with it, and that deserves pin
    tests of its own rather than being folded into a cleanup. }
procedure NTPStartupCheck;
var
   ntpServer: string;
   udp: TIdUDPClient;
   pkt: TIdBytes;
   got: integer;
   t1, t4: SYSTEMTIME;
   t2Time, t3Time: SYSTEMTIME;
   offset: int64;
   i: integer;
begin
   // Wait for the main window to finish initialising before touching the
   // network: a DNS failure can block for 10-15 s and must not delay startup.
   Sleep(3000);

   ntpServer := GetWindowsNTPServer;
   logger.Info('[NTP] Startup time check against %s', [ntpServer]);

   udp := TIdUDPClient.Create(nil);
   try
      udp.Host := ntpServer;
      udp.Port := 123;
      // Two seconds, so an unreachable server cannot hold up the check.
      udp.ReceiveTimeout := 2000;

      SetLength(pkt, 48);
      FillChar(pkt[0], 48, 0);
      pkt[0] := 27;   // LI=0, VN=3, Mode=3 -- an NTP client request

      try
         { UTC now, without the Windows call -- see SystemTimeFromDateTime. }
   SystemTimeFromDateTime(LocalTimeToUniversal(Now), t1);
         udp.SendBuffer(pkt);
         got := udp.ReceiveBuffer(pkt, 2000);
         SystemTimeFromDateTime(LocalTimeToUniversal(Now), t4);
      except
         on E: Exception do
            begin
            // One handler for resolve and send alike: the answer is the same,
            // and a station with no network is the ordinary case here.
            logger.Warn('[NTP] Could not reach %s: %s', [ntpServer, E.Message]);
            ClearThread(NTPStartupThreadID);
            Exit;
            end;
      end;

      if got <> 48 then
         begin
         logger.Warn('[NTP] No usable response from %s (got %d bytes, wanted 48)',
                     [ntpServer, got]);
         ClearThread(NTPStartupThreadID);
         Exit;
         end;
   finally
      udp.Free;
   end;

   // ST_Buffer is 1-based and TIdBytes is 0-based -- the decoder below indexes
   // by the NTP packet's own byte numbering, so the copy keeps that.
   for i := 1 to 48 do
      begin
      ST_Buffer[i] := pkt[i - 1];
      end;

   GetInt64AndSysTimeFromBuffer(33, t2Time);  // T2: server receive timestamp
   GetInt64AndSysTimeFromBuffer(41, t3Time);  // T3: server transmit timestamp

   // NTP offset = ((T2-T1) + (T3-T4)) / 2, in milliseconds
   offset := Round((STToInt64(t2Time) - STToInt64(t1) +
                    STToInt64(t3Time) - STToInt64(t4)) / 2);

   if Abs(offset) > 2000 then
      begin
      logger.Warn('[NTP] Clock offset %d ms from %s - time sync needed',
                  [offset, ntpServer]);
      WarnAboutClockOffset(Abs(offset) div 1000, ntpServer);
      end
   else
      begin
      logger.Info('[NTP] Clock OK: offset=%d ms from %s', [offset, ntpServer]);
      end;

   ClearThread(NTPStartupThreadID);
end;

procedure CheckNTPAtStartup;
begin
   logger.Info('[NTP] Scheduling startup NTP time check');
   tCreateThread(@NTPStartupCheck, NTPStartupThreadID);
end;


end.


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
//   Rewrite of uIO to use InpOut32.dll 32 / 64 bit LPT driver from http://www.highrez.co.uk/
//   Should only need InpOut32.dll in same directory as TR4W.exe
//    Gavin Taylor GM0GAV  25 feb 2015


unit uIO;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  VC,
  TF,
{$IFDEF WINDOWS}
  (* WINDOWS AS WRITTEN. Not Windows by nature -- and an earlier version of
    this comment claimed the latter, which is wrong on the facts.

    What is here is inpout32.dll: direct LPT port access for legacy CW
    keying, loaded on demand through LoadLibrary. That IS Win32, so the
    gate stays. But two things the old comment implied are false, and both
    matter to anyone reading this before a port:

      - LINUX CAN REACH A PARALLEL PORT. The FreePascal wiki's Hardware
        Access page names the route: the `ports` unit for the port[$378]
        syntax, with `fpioperm` from unit `x86` granting access first
        (implemented for Linux x86/x86_64 and FreeBSD). It needs ROOT,
        which is the real objection -- not portability. The non-root
        route the wiki does not cover is ppdev, ioctls on /dev/parport0,
        and that is the one to price if this is ever done.
      - THE DRIVER IS NOT 32-BIT-ONLY. The header above already says
        "32 / 64 bit LPT driver from highrez.co.uk"; the 64-bit build
        ships under a DIFFERENT FILE NAME, so the hardcoded
        'inpout32.dll' in LoadInpOut32 below is a 64-bit blocker on its
        own. Verify that name and its exports against a real x64 build
        before changing it -- do not infer either.

    THE PLATFORM ANSWER, DECIDED 2026-09-08 (NY4I): "LPT stays on windows
    and added for linux. not applicable on mac."

      Windows  keeps inpout32, and THE HARDCODED NAME BELOW IS CORRECT AS
               IT STANDS -- do not "fix" it. TR4W is a 32-bit build, and a
               32-bit application MUST use InpOut32.dll even on 64-bit
               Windows: that DLL carries BOTH drivers and picks at runtime.

               THE x64 NAME GOES WITH THE 64-BIT CHANGE (NY4I, 2026-09-08),
               not before, and the guards NEST rather than compete -- this
               {$IFDEF WINDOWS} is the outer one and stays, with the name
               chosen inside it by {$IFDEF CPU64}: InpOutx64.dll for a 64-bit
               build, inpout32.dll for a 32-bit one. The exports are
               identical between the two, so it is a name and not a rewrite.
               Driver author's notes: docs/inpOut32-64_Info.md
      Linux    A FUTURE INCREMENTAL RELEASE (NY4I, 2026-09-08) -- not this
               one, and not blocked on anything here. It goes behind the
               surface below, so no caller changes when it arrives.

               Do not let an earlier version of this comment mislead you: it
               once said Linux "gets a back end, ppdev first", which was an
               assumption dressed as a plan. WHAT IS VERIFIED is only that
               the FPC wiki offers a ROOT-requiring route (`ports` +
               `fpioperm`). ppdev needs no root but has no FPC bindings
               found, and THE REAL BLOCKER IS TIMING -- tCWSleep's
               non-Windows arm is a plain Sleep that CLAUDE.md says will not
               key a contest, so this is downstream of the HPTimer work.
               BENCH_QUEUE.md has the detail.
      macOS    NOT APPLICABLE. No parallel port to talk to, so the no-op
               below is the finished answer there, not a placeholder.

    So this unit is not waiting to be deleted and not waiting for a decision.
    It is waiting for a per-platform library name and a Linux back end, both
    of which go BEHIND the surface below so no caller changes.
    BENCH_QUEUE.md carries the detail. *)
  Windows,
{$ENDIF}
  SysUtils;


type
  PByte = ^Byte;
  PWORD = ^Word;
  PLongword = ^longword;

  TOffsetType = (otData, otState, otControl);
  TBitOperation = (boSet0, boSet1);
  TBitSet = (bsBIT0, bsBIT1, bsBIT2, bsBIT3, bsBIT4, bsBIT5, bsBIT6, bsBIT7);

  TDlPortWritePortUchar = procedure (Port: Integer; Data: byte); stdcall;//  external 'InpOut32.dll';
  TDlPortReadPortUchar = function (Port: Integer): byte; stdcall;//  external 'InpOut32.dll';
  TIsInpOutDriverOpen =   function ()  : boolean;  stdcall;     //  external 'InpOut32.dll';
  DlPortWritePortUchar = TDlPortWritePortUchar;
  DlPortReadPortUchar = TDlPortReadPortUchar;

  TPinNumber = 1..25;


var
  IOPlugin                              : THandle;
  IOPLuginisloaded                      : boolean;
  inpout32LoadAttempted                 : boolean = False;  // load on demand once; a failed load must not re-warn on every OpenLPT
  DlWriteByte                           : TDlPortWritePortUchar;
  DlReadByte                            : TDlPortReadPortUchar;
  dwStatus                              : DWORD;
  LPTBaseAA                             : array[Parallel1..Parallel3] of Cardinal = ($378, $278, $3BC);

const

  STROBE_SIGNAL                         = bsBIT0; //PIN 01 INVERTED
  PTT_SIGNAL                            = bsBIT2; //PIN 16
  CW_SIGNAL                             = bsBIT3; //PIN 17 INVERTED
  RELAY_SIGNAL                          = bsBIT1; //PIN 14
  MAX_LPT_PORTS                         = 8;

  BIT0                                  : Byte = $01;
  BIT1                                  : Byte = $02;
  BIT2                                  : Byte = $04;
  BIT3                                  : Byte = $08;
  BIT4                                  : Byte = $10;
  BIT5                                  : Byte = $20;
  BIT6                                  : Byte = $40;
  BIT7                                  : Byte = $80;

  // Printer Port pin numbers
  ACK_PIN                               : Byte = 10;
  BUSY_PIN                              : Byte = 11;
  PAPEREND_PIN                          : Byte = 12;
  SELECTOUT_PIN                         : Byte = 13;
  ERROR_PIN                             : Byte = 15;
  STROBE_PIN                            : Byte = 1;
  AUTOFD_PIN                            : Byte = 14;
  INIT_PIN                              : Byte = 16;
  SELECTIN_PIN                          : Byte = 17;


  IOCTL_READ_PORTS                      : Cardinal = $00220050;
  IOCTL_WRITE_PORTS                     : Cardinal = $00220060;




function DriverIsLoaded: boolean;      // returns true if the DLL/Driver is loaded
function GetPortByte(Address: Word; Offset: TOffsetType): Byte;
procedure SetPortByte(Address: Word; Offset: TOffsetType; data: Byte);
procedure DriverCreate;
procedure DriverDestroy;
procedure NoInpOut32Message;
procedure DriverBitOperation(var TempByte: Byte; BitToSet: TBitSet; Operation: TBitOperation);
function OpenLPT(var PortAddress: TLPTBaseAddress; LPT: PortType): boolean;







implementation
uses MainUnit;


procedure DriverCreate;
begin
   if DriverIsLoaded then
      begin
      Exit;
      end;
   // Attempt the load at most once. inpout32.dll is no longer bundled; if it is
   // absent we warn and disable LPT (see NoInpOut32Message) -- without this guard
   // each of the several OpenLPT calls would re-attempt the load and re-warn.
   if inpout32LoadAttempted then
      begin
      Exit;
      end;
   inpout32LoadAttempted := True;

   (* THE LOAD IS THE ONLY WINDOWS-ONLY PART, SO IT IS THE ONLY THING GATED
     (NY4I, 2026-09-08: "windows gate LPT support today. Use inpout32").

     Everything else in this unit -- the port arithmetic, the bit operations,
     OpenLPT -- is plain Pascal over three function POINTERS, and off Windows
     those simply stay nil. DriverIsLoaded then answers False, every caller
     takes its existing not-loaded path, and the LPT surface still COMPILES
     everywhere. Gating the whole unit instead would make `uses uIO` itself
     conditional and push the gate out into logk1ea, LogCfg and MainUnit.

     THE FUNCTION IS LoadLibraryW AND IT WANTS A WIDE STRING, which is why the
     literal is not simply passed along: this file has no `W` suffix by
     accident. Left as-is rather than "fixed" to LoadLibraryA -- see the note
     in the uses clause on why the DLL name is correct as written for a 32-bit
     build.

     WHY NOT dynlibs, WHICH WOULD NEED NO GATE AT ALL: because it would make
     this unit look ready for a Linux back end that does not exist and has not
     been shown to be possible -- the timing blocker is in BENCH_QUEUE.md. A
     gate states the position honestly; a portable loader pointing at a
     Windows DLL name would state a false one. When the Linux back end is
     scheduled, dynlibs is the shape to move to. *)
{$IFDEF WINDOWS}
   IOPlugin := LoadLibraryW('inpout32.dll');
   if (IOPlugin <> 0) then
      begin
      DlWriteByte := TDlPortWritePortUchar(GetProcAddress(IOPlugin, 'Out32'));
      DlReadByte := TDlPortReadPortUchar(GetProcAddress(IOPlugin, 'Inp32'));
      IOPLuginisloaded := TIsInpOutDriverOpen(GetProcAddress(IOPlugin, 'IsInpOutDriverOpen'));
      end
   else
      begin
      NoInpOut32Message;
      end;
{$ELSE}
   (* No LPT support off Windows, and it says so once rather than never --
     "my parallel-port keyer does nothing" is otherwise unanswerable. The
     inpout32LoadAttempted guard above means this is logged a single time. *)
   logger.Info('[LPT] parallel-port support is Windows-only in this build; ' +
               'LPT keying, band output and the relay are disabled.');
{$ENDIF}
end;

procedure DriverDestroy;
begin
{$IFDEF WINDOWS}
  (* Paired with the gated LoadLibraryW in DriverCreate. Off Windows nothing
    was ever loaded, so DriverIsLoaded is False and there is nothing to free --
    but the CALL still has to disappear, because FreeLibrary does not exist
    there either. *)
  if DriverIsLoaded then
     begin
     FreeLibrary(IOPlugin);
     end;
{$ENDIF}
  IOPlugin := 0;
  DlWriteByte := nil;
  DlReadByte := nil;
  IOPLuginisloaded := false;
  inpout32LoadAttempted := false;   // allow a fresh load attempt after an explicit teardown
end;



function DriverIsLoaded: boolean;
begin
    result := IOPLuginisloaded;
end;



function GetPortByte(Address: Word; Offset: TOffsetType): Byte;
begin
  // inpout32.dll absent/not loaded: the port-I/O pointer is nil. Return 0 (a safe
  // "nothing asserted" default) instead of calling through nil. Not every caller
  // guards on DriverIsLoaded(), so this chokepoint must be self-protecting.
  Result := 0;
  if not Assigned(DlReadByte) then
     begin
     Exit;
     end;
  Result := DlReadByte(Address + Word(Offset));
end;

procedure SetPortByte(Address: Word; Offset: TOffsetType; data: Byte);
begin
  // inpout32.dll absent/not loaded: pointer is nil -> no-op rather than crash.
  if not Assigned(DlWriteByte) then
     begin
     Exit;
     end;
  DlWriteByte(Address + Word(Offset), data);
end;




procedure NoInpOut32Message;
var
  msg: string;
begin
  // inpout32.dll is no longer bundled (it was the AV "vulndriver" false-positive
  // trigger on the installer). When it is absent we DISABLE parallel-port (LPT)
  // features and continue -- we must NOT halt, or a stale LPT port left in a
  // user's config would crash startup. Reached only when an LPT port is mapped.
  msg := 'Parallel-port (LPT) features require inpout32.dll, which is no longer'#13#10 +
         'bundled with TR4W. Download it from http://www.highrez.co.uk/ and place'#13#10 +
         'inpout32.dll in the same folder as tr4w.exe. LPT features are disabled'#13#10 +
         'until then; the rest of TR4W is unaffected.';
  showwarning(msg);
end;



procedure DriverBitOperation(var TempByte: Byte; BitToSet: TBitSet; Operation: TBitOperation);
type
  TByteSet = set of 0..SizeOf(Byte) * 8 - 1;
begin
  if Operation = boSet0
    then
//    Exclude(TByteSet(TempByte), integer(BitToSet))
     begin
     TempByte := TempByte and not (1 shl Byte(BitToSet))
     end
  else
     begin
     TempByte := TempByte or (1 shl Byte(BitToSet));
     end;
//    Include(TByteSet(TempByte), integer(BitToSet));
end;


function OpenLPT(var PortAddress: TLPTBaseAddress; LPT: PortType): boolean;
begin
  Result := False;
  if not DriverIsLoaded() then
     begin
     DriverCreate;
     end;
  if not DriverIsLoaded() then Exit;
  PortAddress := LPTBaseAA[LPT];
  Result := True;
end;


end.



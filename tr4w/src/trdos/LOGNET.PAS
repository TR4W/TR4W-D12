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
unit LogNet;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}

(* Has all of the lower level network interface routines in it.

  IT DOES NOT SIT ABOVE LOGK1EA FOR SERIAL, whatever this comment said until
  2026-09-07, and there is no longer anywhere for it to sit: TR4W has ONE
  serial transport, uSerialPort.TSerialPort, over FreePascal's own serial unit
  (vendored as tr4wserial, because FPC does not build that unit for macOS).

  There were FOUR stacks when this note was written, none of them sharing code
  and all of them raw Win32:

    tree.pas + LOGK1EA's handle table   CPU keyer, PTT, packet, rotators
    uSerialPort.TSerialPort             the radio factory
    uWinKey.pas                         its own CreateFileA and DCB
    uYCCCSO2R.pas                       a HID device path, not a COM port

  The first three are one now. tree.pas has no serial code at all -- both
  InitializeSerialPort and TryToOpenCOMPort are deleted -- and LOGK1EA's array
  holds TSerialPort objects for the ports the CW KEYER keys on, which is what
  its name always implied. Rotators own their ports; the WinKeyer owns its one.
  The YCCC box is a HID device and is a different thing entirely. *)

interface

uses
  {Crt,}Tree, {SlowTree,}

  LogK1EA;

var
  //   ActiveMultiPort                 : PortType;

     //  K1EANetworkEnable                     : boolean = False; { Set to TRUE to deal with CT network }

  //   MultiPortBaudRate               : integer = 4800;

  NetDebug                              : boolean;
  NetDebugBinaryOutput                  : file;
  NetDebugBinaryInput                   : file;

procedure SendMultiMessage(Message: string);
procedure SetUpMultiPort;

implementation

uses uNet,
  MainUnit,
  LogWind;

procedure SetUpMultiPort;

begin
  //  if CPUKeyer.SlowInterrupts then
  //    CPUKeyer.SetUpSerialPort(ActiveMultiPort, MultiPortBaudRate, 8, NoParity, 2, 0)
  //  else
  //  CPUKeyer.SetUpSerialPort(ActiveMultiPort, MultiPortBaudRate, 8, NoParity, 2, 1);
end;



procedure SendMultiMessage(Message: string);

{ Works for both N6TR and K1EA Network modes }

var
  CharPointer                           : integer;
  wassend                               : integer;
  NET_Buffer                            : array[1..90] of AnsiChar;
begin
  if length(Message) > 0 then
     begin
     {
      if K1EANetworkEnable then
      begin

                 // We add the checksum and new line unless we already find
                 //  the new line there

        if message[length(message)] <> LineFeed then
        begin
          AddK1EACheckSumToString(message);
          message := message + LineFeed;
        end;
      end
      else
              //wli            Message := SlipMessage(Message);
        message := message;
       }
          { If we don't have enough room for the message, we will have to
             wait until we do as we have no other choice.  }

   if NetDebug then
      begin
      //{WLI}if CPUKeyer.SerialPortOutputBuffer[ActiveMultiPort].FreeSpace < length(Message) then
      //{WLI}                SendMorse ('PBF PBF');

      //{WLI}            SaveAndSetActiveWindow (BandMapWindow);
      //{WLI}            GoToXY (1, 22);
      //{WLI}            ClrEol;
      end;

     //{WLI}         while not CPUKeyer.SerialPortOutputBuffer[ActiveMultiPort].FreeSpace >= length(Message) do ;

   for CharPointer := 1 to length(Message) do
      begin
      //               CPUKeyer.SerialPortOutputBuffer[ActiveMultiPort].AddEntry(Ord(Message[CharPointer]));
  NET_Buffer[CharPointer] := AnsiChar(Message[CharPointer]);

  if NetDebug then
     begin
     BlockWrite(NetDebugBinaryOutput, NET_Buffer[CharPointer], 1);

     if (Message[CharPointer] >= ' ') and
       (Message[CharPointer] <= 'z') then
        begin
        Write(Message[CharPointer]);
        end;
     end;
      end;
   if not NetIsConnected then Exit;
   wassend := SendToNet(NET_Buffer, length(Message));
//  if wassend + 1 <> CharPointer then         // 4.79.4 charpointer not used
       //      showmessage('Can`t sent' + #13 + message + #13 + 'Check connection');
                //{WLI}         if NetDebug then  RestorePreviousWindow;
     end;
  
end;

begin
  //   ActiveMultiPort := NoPort;
end.

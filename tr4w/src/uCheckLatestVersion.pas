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
unit uCheckLatestVersion;
{$I tr4w.inc}

interface

uses
  uAnsiStr,
  TF,
  Version,
  VC,
  LogSCP,
  LogWind,
  LogRadio,
  uGetScores,
  Windows,
  WinSock2,
utils_text,
  utils_net
  ,
  uTR4WStrings;

procedure CheckLatestVersion;

implementation
uses MainUnit;

procedure CheckLatestVersion;
label 1;
var
 
  p                                     : PAnsiChar;
  TempSocket                            : Cardinal;
const
  checkVersionRequest                   : PAnsiChar =
    'GET /include_pages/version.txt HTTP/1.1'#13#10 +
    'User-Agent: ' + TR4W_CURRENTVERSION + '_%s_%s_%s_%s' + #13#10 +
    'Host: www.tr4w.net'#13#10 +
    #13#10;                      // n4af 04.42.5
begin
  // tr4w.NET, not tr4w.com.  It dialled 'tr4w.com' while sending
  // 'Host: www.tr4w.net' in the request three lines above -- so the two
  // disagreed, and the version check could only ever have worked if .com served
  // the same content.  Found on 2026-08-22 when the routine was given its first
  // caller; it had never run, so nothing had exercised the mismatch.
  if not GetConnection(TempSocket, 'www.tr4w.net', 80, SOCK_STREAM) then
     begin
     ShowSyserror(WSAGetLastError);
     Exit;
     end;

  WinSock2.Send(TempSocket, wsprintfBuffer, TF.Format(wsprintfBuffer, checkVersionRequest, @MyCall[1], InterfacedRadioTypeSA[Radio1.RadioModel], InterfacedRadioTypeSA[Radio2.RadioModel], BA[CD.MasterFileExists]), 0);
  Windows.Sleep(2000);
  if WinSock2.recv(TempSocket, GetScoresBuffer, SizeOf(GetScoresBuffer), 0) <= 0 then
     begin
     ShowSyserror(WSAGetLastError);
     goto 1;
     end;

//  ShowMessage(GetScoresBuffer);
  p := uAnsiStr.StrPos(GetScoresBuffer, #13#10#13#10);
  if p <> nil then
     begin
     inc(p, 4);
 //    ShowMessage(@TR4W_CURRENTVERSION[8]);

     if StrComp(p, @AnsiString(TR4W_CURRENTVERSION)[8]) <= 0 then
        begin
        ShowMessage(TC_YOU_ARE_USING_THE_LATEST_VERSION + ' - ' + TR4W_CURRENTVERSION_NUMBER + '.');
        goto 1;
        end;

     TF.Format(wsprintfBuffer, PAnsiChar(WinAnsi(TC_VERSIONONSERVER + ': %s. ' + TC_THISVERSION2 + ': ' + TR4W_CURRENTVERSION + '.'#13#10 + TC_DOWNLOADIT)), p);
     if YesOrNo(tr4whandle, wsprintfBuffer) = IDYES then
        begin
        OpenURL(TR4W_DOWNLOAD_LINK);
        end;
     end;
  1:
  closesocket(TempSocket);
end;

end.


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
unit uInet;
{$I tr4w.inc}


{**************************************************************************
  This is dead code. Do not use this. Make use of the Indy HTTP (TIdHTTP).
  There are several examples of doing this in the code
  This module could be removed int he future
  Tom Schaefer NY4I 2026-04-14
***************************************************************************}
interface

uses
  SysUtils,
  Classes,
  WinInet,
{$IFDEF FPC}
  // FPC's fcl-base spells it base64/EncodeStringBase64; Delphi's RTL spells it
  // EncdDecd/EncodeString.  One call site, one line different -- shimmed here
  // rather than owned, because both RTLs already have a correct RFC 4648
  // encoder and re-implementing one would be gold-plating, not portability.
  base64;
{$ELSE}
  EncdDecd;
{$ENDIF}

function SslInet(Const AServer, AUrl, AData, ALogin, APass: AnsiString; isSSL: Boolean = True): AnsiString;

implementation

function SslInet(Const AServer, AUrl, AData, ALogin, APass: AnsiString; isSSL: Boolean = True): AnsiString;
var
  aBuffer     : Array[0..4096] of Char;
  Header      : TStringStream;
  BufStream   : TMemoryStream;
  sMethod     : AnsiString;
  BytesRead   : Cardinal;
  pSession    : HINTERNET;
  pConnection : HINTERNET;
  pRequest    : HINTERNET;
  authEncode  : AnsiString;
begin

  Result := '';

  pSession := InternetOpenW(nil, INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);

  if Assigned(pSession) then
    try

     case isSSL of
       True  :  pConnection := InternetConnectW(pSession, PChar(AServer), INTERNET_DEFAULT_HTTPS_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
       False :  pConnection := InternetConnectW(pSession, PChar(AServer), INTERNET_DEFAULT_HTTP_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
     end;

    if Assigned(pConnection) then
      try

        if (AData = '') then
           begin
           sMethod := 'GET'
           end
        else
           begin
           sMethod := 'POST';
           end;

        case isSSL of
          True  : pRequest := HTTPOpenRequestW(pConnection, PChar(sMethod), PChar(AURL), nil, nil, nil, INTERNET_FLAG_SECURE  or INTERNET_FLAG_KEEP_CONNECTION, 0);
          False : pRequest := HTTPOpenRequestW(pConnection, PChar(sMethod), PChar(AURL), nil, nil, nil, INTERNET_SERVICE_HTTP, 0);
        end;

        if Assigned(pRequest) then
          try

{$IFDEF FPC}
            authEncode := base64.EncodeStringBase64(ALogin + ':' + APass);
{$ELSE}
            authEncode := EncdDecd.EncodeString(ALogin + ':' + APass);
{$ENDIF}

            Header := TStringStream.Create('');

            with Header do
               begin
               WriteString('Host: ' + AServer + sLineBreak);
               WriteString('Authorization: Basic ' + authEncode + sLineBreak);
               WriteString('Connection: close' + sLineBreak + sLineBreak);
               end;

            HttpAddRequestHeadersW(pRequest, PChar(Header.DataString), Length(Header.DataString), HTTP_ADDREQ_FLAG_ADD);

            if HTTPSendRequestW(pRequest, nil, 0, Pointer(AData), Length(AData)) then
               begin

               BufStream := TMemoryStream.Create;
               try

                  while InternetReadFile(pRequest, @aBuffer, SizeOf(aBuffer), BytesRead) do
                     begin
                     if (BytesRead = 0) then Break;
                     BufStream.Write(aBuffer, BytesRead);
                     end;

                  aBuffer[0] := #0;
                  BufStream.Write(aBuffer, 1);
                  Result := PChar(BufStream.Memory);

               finally
                 FreeAndNil(BufStream);
               end;

               end;

          finally
            InternetCloseHandle(pRequest);
            FreeAndNil(Header);
          end;

      finally
        InternetCloseHandle(pConnection);
      end;

    finally
      InternetCloseHandle(pSession);
    end;
    
end;

end.

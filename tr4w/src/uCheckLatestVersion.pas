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

(* IS THERE A NEWER TR4W? -- ASKED OF A JSON ENDPOINT, OVER INDY.

  NY4I, 2026-09-08, and this is a PLACEHOLDER by his description: "assume the
  uCheckLatestVersion will call a URL on https://tr4w.net/version.json and that
  file [has] a single field called version. Use Indy to get the file. If you
  get an error accessing it, just [log] it in the log. We will update the exact
  fields in the file (and to handle multi-platform) later."

  WHAT THIS REPLACED, because the shape of it is the reason the feature was
  switched off. It was a hand-written HTTP/1.1 request pushed down a RAW
  WINSOCK SOCKET on port 80, followed by `Sleep(2000)` ON THE UI THREAD, a
  single `recv` into a shared global buffer, and a hunt for the blank line that
  separates headers from body. Whatever came back after that blank line WAS
  TREATED AS THE VERSION. So when tr4w.net answered with a Cloudflare error
  page, the operator was shown

      The last version on server: <html><head><title>400 Bad Request</title>...

  and invited to download it. That is why Check for Updates came off the menu
  on 2026-08-28, and why the fix is a PARSEABLE endpoint rather than a tidier
  socket: a JSON object either has a `version` string or it does not.

  ERRORS ARE LOGGED, NEVER SHOWN. A failed update check is not the operator's
  problem in the middle of a contest, and the old code's habit of showing them
  whatever arrived is exactly what this removes. The only things that reach the
  screen are the two real answers: you are current, or here is a newer one.

  STILL SYNCHRONOUS ON THE CALLING THREAD, and that is a known debt rather than
  an oversight -- CLAUDE.md lists moving its socket work off the main thread as
  a bench-queue item. What is gone is the unconditional two-second sleep; the
  timeouts below bound the wait instead, and they are short on purpose. *)

interface

procedure CheckLatestVersion;

implementation

uses
  SysUtils,
  Classes,
  IdHTTP,
  IdSSLOpenSSL,
  IdComponent,
  fpjson,
  LCLType,        // IDYES -- what YesOrNo answers with
  uJSON,          // GetJSON + the TJSONObject helpers, as the settings store uses
  Version,        // TR4W_CURRENTVERSION, TR4W_CURRENTVERSION_NUMBER
  VC,             // TR4W_DOWNLOAD_LINK
  TF,             // OpenURL
  MainUnit,       // logger, YesOrNo, ShowMessage
  uTR4WStrings;

const
  (* PROVISIONAL, and expected to change -- NY4I: "We will update the exact
    fields in the file (and to handle multi-platform) later." Both the URL and
    the field name are here so that change is one edit. *)
  VERSION_URL   = 'https://tr4w.net/version.json';
  VERSION_FIELD = 'version';

  { Short on purpose: this runs on the calling thread, so the worst case is how
    long the operator waits for a window that was never important. }
  CONNECT_TIMEOUT_MS = 5000;
  READ_TIMEOUT_MS    = 5000;

{ The body of VERSION_URL, or '' with the reason logged. }
function FetchVersionDocument: string;
var
   http : TIdHTTP;
   ssl  : TIdSSLIOHandlerSocketOpenSSL;
begin
   Result := '';
   http := TIdHTTP.Create(nil);
   ssl  := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
   try
      try
         ssl.SSLOptions.Method := TIdSSLVersion(sslvTLSv1_2);
         http.IOHandler        := ssl;
         http.HandleRedirects  := True;
         http.ConnectTimeout   := CONNECT_TIMEOUT_MS;
         http.ReadTimeout      := READ_TIMEOUT_MS;
         http.Request.UserAgent := 'TR4W ' + string(TR4W_CURRENTVERSION_NUMBER);

         logger.Debug('[VersionCheck] GET %s', [VERSION_URL]);
         Result := http.Get(VERSION_URL);
      except
         (* EVERY failure ends here and goes to the log: no network, no DNS, a
           TLS refusal, a 404, a timeout. The operator is told nothing, which
           is the instruction and also the right answer -- see the header. *)
         on E: Exception do
            begin
            logger.Error('[VersionCheck] %s could not be read (%s: %s)',
                         [VERSION_URL, E.ClassName, E.Message]);
            Result := '';
            end;
      end;
   finally
      http.Free;
      ssl.Free;
   end;
end;

(* The one field, or '' with the reason logged.

  GetJSON RAISES on malformed input rather than returning nil, which is the
  fpjson behaviour uJSON's header calls out -- so the parse is inside the try
  as much as the fetch is. A body that is not an object, or an object without
  a `version` STRING, is the Cloudflare-error case in its modern form and is
  treated as a failure rather than as a version. *)
function VersionFrom(const aBody: string): string;
var
   data : TJSONData;
   obj  : TJSONObject;
   val  : TJSONValue;
begin
   Result := '';
   if Trim(aBody) = '' then
      begin
      logger.Error('[VersionCheck] %s returned an empty document', [VERSION_URL]);
      Exit;
      end;

   data := nil;
   try
      try
         (* UTF8Encode, not an implicit narrowing: GetJSON takes UTF8String
           and Indy hands back a UnicodeString, so the conversion happens
           either way. Stated here, and it is the RIGHT conversion -- a JSON
           document is UTF-8 by definition, so encoding it is what the parser
           expects rather than a lossy cast to the ANSI codepage. *)
         data := GetJSON(UTF8Encode(aBody));
      except
         on E: Exception do
            begin
            logger.Error('[VersionCheck] %s is not JSON (%s: %s)',
                         [VERSION_URL, E.ClassName, E.Message]);
            Exit;
            end;
      end;

      if not (data is TJSONObject) then
         begin
         logger.Error('[VersionCheck] %s is JSON but not an object', [VERSION_URL]);
         Exit;
         end;

      obj := TJSONObject(data);
      val := obj.GetValue(VERSION_FIELD);
      if (val <> nil) and (val is TJSONString) then
         begin
         Result := JSONText(val);
         end;
      if Result = '' then
         begin
         logger.Error('[VersionCheck] %s has no "%s" string field',
                      [VERSION_URL, VERSION_FIELD]);
         end;
   finally
      data.Free;
   end;
end;

procedure CheckLatestVersion;
var
   latest  : string;
   current : string;
begin
   latest := VersionFrom(FetchVersionDocument);
   if latest = '' then
      begin
      { Already logged, with the reason. Nothing reaches the screen. }
      Exit;
      end;

   current := string(TR4W_CURRENTVERSION_NUMBER);
   logger.Info('[VersionCheck] server says %s, this build is %s', [latest, current]);

   (* A PLAIN STRING COMPARE, and it is not good enough -- stated rather than
     hidden. '5.0.10' sorts BELOW '5.0.9' this way. The old code had the same
     flaw with StrComp, so this is not a regression, and a proper component
     compare belongs with the endpoint's real shape when NY4I settles the
     multi-platform fields. *)
   if latest = current then
      begin
      ShowMessage(TC_YOU_ARE_USING_THE_LATEST_VERSION + ' - ' + current + '.');
      Exit;
      end;

   if latest < current then
      begin
      { Ahead of the server -- a test build. Say nothing to the operator. }
      logger.Info('[VersionCheck] this build is newer than the server''s; nothing to offer');
      Exit;
      end;

   if YesOrNo(SysUtils.Format('%s: %s. %s: %s.'#13#10'%s',
                              [TC_VERSIONONSERVER, latest,
                               TC_THISVERSION2, current,
                               TC_DOWNLOADIT])) = IDYES then
      begin
      OpenURL(TR4W_DOWNLOAD_LINK);
      end;
end;

end.

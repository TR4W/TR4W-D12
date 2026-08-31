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
unit uGetScores;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  uConfigValues,   // Config -- migrated settings

  TF,
  Version,
  VC,
//  ShellAPI,
  uMults,
  LogEdit,
  PostUnit,
  Windows,
  Messages,
  LogStuff,
  LogDupe,
  LogWind,
  utils_net,
  utils_file,
  Classes,
  SysUtils,
  IdHTTP,
  IdSSLOpenSSL,
  uCTYDAT,              // Issue #930 -- ctyGetCountryID / ctyGetCQZone / ctyGetITUZone (native Pascal, no cty.dll)
  LogGrid,              // Issue #930 -- MyGrid
  Tree
  ,
  uTR4WStrings;
procedure CreateConnectionAndSendReportToGetScores;
procedure RunPOSTGetScoresThread;
//function MakePOSTRequest: integer;
//function MakePOSTRequestForRDXC2010: integer;
function MakePOSTRequestNew: integer;
procedure ShowGetScoresStatus(Status: string);
procedure CheckServerAnswer(AnswerLength: integer);

// Issue #783 -- HamScore RTC support reuses the dynamicresults fragment
// the existing scoreboard poster already builds.  This returns just the
// XML container (no <?xml> prolog, no `xml=` form-encoding prefix), so
// the RTC uploader can wrap it in a multi-container POST.
function BuildDynamicResultsXml: AnsiString;
//procedure SendOnLineResultsToRDXC2010Site;

var
  GetScoresPostingID                    : integer;
  GetScoresBuffer                       : array[0..4096 - 1] of AnsiChar;
  GetScoresThreadID                     : Cardinal;
  GetScoresThreadHandle                 : Cardinal;
  GetScoresAnswerFileName               : array[0..255] of AnsiChar;
const

  GSCR                                  = ''; //#13#10;
{
  XML                                   =
    'xml=<?xml version="1.0"?><dynamicresults>' +
    GSCR + '<contest>%s</contest>' +
    GSCR + '<call>%s</call>' +
    GSCR + '<class ops="%s" mode="%s" power="%s" bands="%s"></class>' +
    GSCR + '<breakdown>' +
//    '%s' +
  '</breakdown>' +
    GSCR + '<score>%u</score>' +
    GSCR + '<timestamp>%s</timestamp>' + GSCR + '</dynamicresults>';
}
implementation
uses
  MainUnit,
  uAnsiStr,
  uPostScoresForm,   // PostScoresShowStatus -- the window is an LCL form
  uCabrilloHeader;   // the Cabrillo header, from settings\tr4w.json

procedure RunPOSTGetScoresThread;
begin
  if GetScoresThreadID = 0 then
     begin
     logger.Debug('Calling tCreateThread from RunPOSTGetScoresThread');
     GetScoresThreadHandle := tCreateThread(@CreateConnectionAndSendReportToGetScores, GetScoresThreadID);
     logger.Debug('Created GetScores thread with threadid of %d',[GetScoresThreadID] );
     end;
//  CreateConnectionAndSendReportToGetScores;
end;

procedure CreateConnectionAndSendReportToGetScores;
var
   http : TIdHTTP;
   ssl  : TIdSSLIOHandlerSocketOpenSSL;
   PostBody  : TStringStream;
   sURL      : string;
   h         : HWND;
begin
   ShowGetScoresStatus(TC_CONNECT);
   MakePOSTRequestNew; // fills GetScoresBuffer with the URL-encoded POST body

   sURL := string(Config.GetScoresSeverPostingAddress);

   http := TIdHTTP.Create(nil);
   ssl  := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
   try
      // Attach SSL handler only for https:// URLs so plain http:// custom
      // URLs (if configured by the operator) still work without TLS.
      if (Length(sURL) >= 8) and
         (LowerCase(Copy(sURL, 1, 8)) = 'https://') then
         begin
         ssl.SSLOptions.Method := TIdSSLVersion(sslvTLSv1_2);
         http.IOHandler := ssl;
         end;

      http.HandleRedirects := True;
      http.Request.UserAgent    := TR4W_CURRENTVERSION;
      http.Request.ContentType  := 'application/x-www-form-urlencoded';

      PostBody := TStringStream.Create(string(PAnsiChar(@GetScoresBuffer)));
      try
         logger.Debug('Score post: URL = %s', [sURL]);
         http.Post(sURL, PostBody);
      finally
         PostBody.Free;
      end;

      if http.ResponseCode = 200 then
         begin
         // Save the server response for diagnostics
         if tOpenFileForWrite(h, GetScoresAnswerFileName) then
            begin
            sWriteFile(h, GetScoresBuffer, lstrlenA(GetScoresBuffer));
            CloseHandle(h);
            end;
         ShowGetScoresStatus(TC_UPLOADEDSUCCESSFULLY);
         end
      else
         begin
         logger.Warn('Score post: server returned %d for %s', [http.ResponseCode, sURL]);
         ShowGetScoresStatus(TC_FAILEDTOCONNECTTOGETSCORESORG);
         end;

   except
      on E: Exception do
         begin
         logger.Error('Score post failed for %s: %s', [sURL, E.Message]);
         ShowGetScoresStatus(TC_FAILEDTOCONNECTTOGETSCORESORG);
         end;
   end;

   http.Free;
   ssl.Free;
   GetScoresThreadID := 0;
   CloseHandle(GetScoresThreadHandle);
end;

{ CALLED FROM THE UPLOAD WORKER THREAD as well as from the main one --
  CreateConnectionAndSendReportToGetScores runs under tCreateThread and reports
  every stage through here.

  It used to be SetDlgItemTextA against the dialog's static, which was safe from
  a worker BY ACCIDENT: SetDlgItemText is a kernel call and Windows marshals it
  to the window's thread.  The window is an LCL form now and assigning a Caption
  marshals nothing, so the hop is explicit and lives with the form. }
procedure ShowGetScoresStatus(Status: string);
begin
  PostScoresShowStatus(GetTimeString + ' : ' + Status);
end;

procedure CheckServerAnswer(AnswerLength: integer);
label
  1;
var
  i                                     : integer;
  p                                     : string;   // was PAnsiChar; holds a resourcestring now
begin
  p := '';
  if AnswerLength < 1 then
     begin
     p := TC_NOANSWERFROMSERVER;
     goto 1;
     end;

  for i := 0 to AnswerLength - 1 - 4 do
    if GetScoresBuffer[i] in [#13, #10] then
       begin
       GetScoresBuffer[i] := #0;
       p := string(PAnsiChar(@GetScoresBuffer[13]));
       Break;
       end;

  for i := 0 to AnswerLength - 1 - 4 do
     begin
     //    TempInteger := PInteger(@GetScoresBuffer[i])^;
     //    if TempInteger = $462D4B4F then {OK-F} p := TC_UPLOADEDSUCCESSFULLY;
     //    if TempInteger = $6176614A then {Java} p := TC_UPLOADEDSUCCESSFULLY;
     //    if TempInteger = $4C494146 then {FAIL} p := TC_FAILEDTOLOAD;
     end;
  1:
  ShowGetScoresStatus(p);
end;
{
procedure SendOnLineResultsToRDXC2010Site;
begin
  WinSock2.Send(GetScoresSocket, GetScoresBuffer, MakePOSTRequestForRDXC2010, 0);
end;
}

// Issue #930 -- refactored to call BuildDynamicResultsXml as the single source
// of truth for the <dynamicresults> payload.  Previously this function
// duplicated the entire XML build, with a maintenance comment warning that
// the two had to stay aligned.  Now MakePOSTRequestNew is a thin wrapper that
// prepends the form-encoding key and the XML prolog and writes the result
// into GetScoresBuffer for the legacy 5-minute scoreboard poster.
function MakePOSTRequestNew: integer;
var
   sBody: AnsiString;
   begin
   sBody := AnsiString('xml=<?xml version="1.0"?>') + BuildDynamicResultsXml;
   lstrcpyA(GetScoresBuffer, PAnsiChar(WinAnsi(sBody)));
   logger.Debug('[MakePOSTRequestNew] %s', [GetScoresBuffer]);
   Result := Windows.lstrlenA(GetScoresBuffer);
   end;

// ---------------------------------------------------------------------------
// Issue #783 -- standalone <dynamicresults> builder for the HamScore RTC
// uploader (uHamScore).  Mirrors the XML produced by MakePOSTRequestNew but
// returns an AnsiString so the RTC worker thread can build its own copy
// without sharing the GetScoresBuffer global with the existing 5-minute
// scoreboard poster.
//
// IMPORTANT: when MakePOSTRequestNew's XML schema changes, mirror the change
// here.  The two functions must stay aligned because hamscore.com expects
// the same dynamicresults shape.
// ---------------------------------------------------------------------------

// Issue #930 -- read a Cabrillo-summary field from tr4w.ini [REPORT].
// Used for <club> (key=_CLUB) and <overlay> (key=_CATEGORY-OVERLAY) which the
// user enters in the Cabrillo summary dialog (uCbrSum) rather than in a CFG.
function ReadCabrilloSummaryField(const Key: PAnsiChar): string;
var
   buf: array[0..255] of AnsiChar;
   n:   Cardinal;
   begin
   // The Cabrillo header lives in settings\tr4w.json now, not tr4w.ini's
   // [REPORT] section (2026-08-16).  CABRILLOSECTION, not the ERMAK section:
   // the scores server takes the standard Cabrillo tags, and an ERMAK contest
   // posts the same club and overlay it always did.
   uAnsiStr.StrPLCopy(buf, AnsiString(HeaderValue(string(CABRILLOSECTION), string(Key))),
                      SizeOf(buf) - 1);
   n := uAnsiStr.StrLen(buf);
   if n = 0 then
      begin
      Result := ''
      end
   else
      begin
      Result := Trim(string(buf));
      end;
   end;

// Issue #930 -- escape XML special chars so user-entered strings (club name,
// city, etc.) can't break the dynamicresults parser at the receiver.
function XmlEscape(const s: string): string;
var
   i: Integer;
   c: Char;
   begin
   Result := '';
   for i := 1 to Length(s) do
      begin
      c := s[i];
      case c of
         '&': Result := Result + '&amp;';
         '<': Result := Result + '&lt;';
         '>': Result := Result + '&gt;';
         '"': Result := Result + '&quot;';
         '''': Result := Result + '&apos;';
         else
            Result := Result + c;
         end;
      end;
   end;

function BuildDynamicResultsXml: AnsiString;
var
  TempBand:     BandType;
  TempMode:     ModeType;
  m:            RemainingMultiplierType;
  BandStr:      string;
  nTotal:       Integer;
  nQSOs:        Integer;
  sContest:     string;
  ts:           string;
  sClub:        string;
  sOverlay:     string;
  sDXCC:        DXMultiplierString;
  sSection:     string;
  sState:       string;
  sGrid4:       string;
  sZone:        string;
  qth:          string;
const
  RTCMultStr:   array[RemainingMultiplierType] of string = ('', 'state', 'country', 'zone', 'prefix');
  RTCModeStr:   array[ModeType] of string = ('CW', 'DIGI', 'PH', 'ALL', '', '');
begin
  nTotal := 0;
  nQSOs  := 0;

  if Length(ContestsArray[Contest].ADIFName) = 0 then
     begin
     sContest := ContestTypeSA[Contest]
     end
  else
     begin
     sContest := ContestsArray[Contest].ADIFName;
     end;

  // <ops> = MyCall (single-op) -- issue #930.  Multi-op operator-list comes
  // from the Cabrillo summary _OPERATORS in production use; defer until users
  // request it (the spec accepts a single call here for single-op).
  // <club> + <overlay> come from the Cabrillo summary stored in tr4w.ini
  // [REPORT] -- single source of truth with the Cabrillo header.
  sClub    := ReadCabrilloSummaryField('_CLUB');
  sOverlay := ReadCabrilloSummaryField('_CATEGORY-OVERLAY');
  if sOverlay = '' then
     begin
     sOverlay := 'N/A';
     end;

  Result := AnsiString(Format(
    '<dynamicresults>' +
    '<soft>TR4W</soft>' +
    '<version>%s</version>' +
    '<contest>%s</contest>' +
    '<call>%s</call>' +
    '<ops>%s</ops>',
    [TR4W_CURRENTVERSION_NUMBER,
     XmlEscape(sContest),
     XmlEscape(string(MyCall)),
     XmlEscape(string(MyCall))]));

  if sClub <> '' then
     begin
     Result := Result + AnsiString('<club>' + XmlEscape(sClub) + '</club>');
     end;

  Result := Result + AnsiString(Format(
    '<class ops="%s" mode="%s" power="%s" bands="%s" transmitter="%s" assisted="%s" overlay="%s"></class>',
    [tCategoryOperatorSA[CategoryOperator],
     tCategoryModeSA[CategoryMode],
     tCategoryPowerSA[CategoryPower],
     tCategoryBandSA[CategoryBand],
     tCategoryTransmitterSA[CategoryTransmitter],
     tCategoryAssistedSA[CategoryAssisted],
     XmlEscape(sOverlay)]));

  // <qth> block -- emit only sub-elements whose source is set.
  //
  // Sourcing notes:
  //   <dxcccountry>: CTY.DAT lookup on MyCall (definitive).
  //   <cqzone>:      CTY.DAT lookup on MyCall.  Do NOT use MyZone -- its
  //                  meaning flips per contest (CQ-zone-mode vs ITU-zone-mode
  //                  per ContestsBooleanArray bit 6), so it cannot be trusted
  //                  as a CQ-zone source.
  //   <iaruzone>:    MY ITU ZONE CFG when explicit (multi-zone country
  //                  override), else CTY.DAT ITU lookup which honors
  //                  per-callsign exceptions in CTY.DAT.
  //   <arrlsection>: MY SECTION CFG, falling back to Cabrillo summary
  //                  [REPORT]/_LOCATION (where users typically enter it).
  //   <stprvoth>:    MY STATE CFG, falling back to Cabrillo summary
  //                  [REPORT]/_ADDRESS-STATE-PROVINCE.
  //   <grid4>/<grid6>: <grid6> when MyGrid is 6+ chars (use first 6 with
  //                    subsquare lowercased per Maidenhead convention);
  //                    <grid4> when 4 chars; nothing when empty.
  sDXCC    := '';
  if MyCall <> '' then
     begin
     sDXCC := ctyGetCountryID(MyCall);
     end;

  sSection := Trim(string(MySection));
  if sSection = '' then
     begin
     sSection := ReadCabrilloSummaryField('_LOCATION');
     end;

  sState := Trim(string(MyState));
  if sState = '' then
     begin
     sState := ReadCabrilloSummaryField('_ADDRESS-STATE-PROVINCE');
     end;

  sZone := '';
  if MyCall <> '' then
     begin
     sZone := IntToStr(ctyGetCQZone(MyCall));
     end;

  // Grid: emit <grid6> when MyGrid has the subsquare (6+ chars), <grid4>
  // when only the 4-char square is known.  The New Contest dialog
  // truncates MyGrid to 4 chars for RTC and many other contests
  // (uNewContest.pas:419), so 4 chars is the common case; a 6-char value
  // appears when the user manually set MY GRID in tr4w.ini or used a
  // contest dialog that prompts for the full grid.
  sGrid4 := Trim(string(MyGrid));

  qth := '';
  if sDXCC <> '' then
     begin
     qth := qth + '<dxcccountry>' + XmlEscape(string(sDXCC)) + '</dxcccountry>';
     end;
  if sZone <> '' then
     begin
     qth := qth + '<cqzone>' + XmlEscape(sZone) + '</cqzone>';
     end;
  if MyITUZone > 0 then
     begin
     qth := qth + '<iaruzone>' + IntToStr(MyITUZone) + '</iaruzone>'
     end
  else if MyCall <> '' then
     begin
     qth := qth + '<iaruzone>' + IntToStr(ctyGetITUZone(MyCall)) + '</iaruzone>';
     end;
  if sSection <> '' then
     begin
     qth := qth + '<arrlsection>' + XmlEscape(sSection) + '</arrlsection>';
     end;
  if sState <> '' then
     begin
     qth := qth + '<stprvoth>' + XmlEscape(sState) + '</stprvoth>';
     end;
  if Length(sGrid4) >= 6 then
     begin
     qth := qth + '<grid6>' +
       XmlEscape(UpperCase(Copy(sGrid4, 1, 4)) + LowerCase(Copy(sGrid4, 5, 2))) +
       '</grid6>'
     end
  else if Length(sGrid4) >= 4 then
     begin
     qth := qth + '<grid4>' + XmlEscape(UpperCase(Copy(sGrid4, 1, 4))) + '</grid4>';
     end;
  if qth <> '' then
     begin
     Result := Result + AnsiString('<qth>' + qth + '</qth>');
     end;

  Result := Result + AnsiString('<breakdown>');

  // Per-band/mode <qso> rows + <total>.
  for TempBand := Band160 to AllBands do
     begin
     for TempMode := CW to Phone do
        begin
        if QSOTotals[TempBand, TempMode] = 0 then Continue;

        if TempBand = AllBands then
           begin
           BandStr := 'total';
           nQSOs   := nTotal;
           end
        else
           begin
           BandStr := string(BandStringsArrayWithOutSpaces[TempBand]);
           nQSOs   := QSOTotals[TempBand, TempMode];
           nTotal  := nTotal + nQSOs;
           end;

        Result := Result + AnsiString(Format(
          '<qso band="%s" mode="%s">%d</qso>',
          [BandStr, RTCModeStr[TempMode], nQSOs]));
        end;
     end;

  Result := Result + AnsiString(Format(
    '<qso band="total" mode="ALL">%d</qso>', [nQSOs]));

  // Per-band/mode <mult> rows.
  for TempBand := Band160 to AllBands do
     begin
     for TempMode := CW to Both do
        begin
        for m := Succ(Low(RemainingMultiplierType)) to High(RemainingMultiplierType) do
           begin
           if mo.MTotals[TempBand, TempMode, m] = 0 then Continue;

           if TempBand = AllBands then
              begin
              BandStr := 'total'
              end
           else
              begin
              BandStr := string(BandStringsArrayWithOutSpaces[TempBand]);
              end;

           Result := Result + AnsiString(Format(
             '<mult band="%s" mode="%s" type="%s">%d</mult>',
             [BandStr, RTCModeStr[TempMode], RTCMultStr[m],
              mo.MTotals[TempBand, TempMode, m]]));
           end;
        end;
     end;

  // Per-band <point> totals + grand total -- issue #930.  Mirrors the WRTC
  // UDP emitter in LOGSUBS2 (SendScoreToUDP) which uses QSOPointTotals.
  for TempBand := Band160 to AllBands do
     begin
     if QSOPointTotals[TempBand, Both] = 0 then Continue;
     if TempBand = AllBands then
        begin
        BandStr := 'total'
        end
     else
        begin
        BandStr := string(BandStringsArrayWithOutSpaces[TempBand]);
        end;
     Result := Result + AnsiString(Format(
        '<point band="%s" mode="ALL">%d</point>',
        [BandStr, QSOPointTotals[TempBand, Both]]));
     end;

  tGetSystemTime;
  ts := SystemTimeToString(UTC);
  Result := Result + AnsiString(Format(
    '</breakdown><score>%d</score><timestamp>%s</timestamp></dynamicresults>',
    [TotalScore, ts]));
end;

end.


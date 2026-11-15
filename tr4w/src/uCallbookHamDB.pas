unit uCallbookHamDB;
{$I tr4w.inc}

(* THE hamdb.org CALLBOOK PROVIDER (issue 321).  No login.

   GET https://api.hamdb.org/v1/<call>/json/<appname>

   HTTPS, not the http:// the service's own page shows: uHTTPDownload refuses a
   plaintext request unless a caller opts in, and the service answers over TLS.

   A FOUND CALL answers
      {"hamdb":{"version":"1","callsign":{"call":"NY4I","class":"E",
        "expires":"06/16/2032","status":"A","grid":"EL88pa","lat":"28.03",
        "lon":"-82.72","fname":"THOMAS","mi":"M","name":"SCHAEFER","suffix":"",
        "addr1":"...","addr2":"Clearwater","state":"FL","zip":"33761",
        "country":"United States"},"messages":{"status":"OK"}}}

   AN UNKNOWN CALL (observed live, 2026-11-14, for a made-up call) answers
   HTTP 200 with every callsign field -- call included -- set to the literal
   "NOT_FOUND" and messages.status "NOT_FOUND".  So the test for "found" is
   messages.status = "OK" AND a call that is not NOT_FOUND, and any other field
   holding NOT_FOUND is read as empty.

   A CALL WITH A SLASH IS NOT FOUND AT hamdb (observed live, same day).  The percent-encoded form (W1AW%2F4) is answered with an
   Apache HTML 404 page, and the literal slash with an empty 200.  Both end in
   Found=False here (the HTML is not JSON), so portable calls are simply not
   found at hamdb; that is the service's limit, not a defect in the encoding. *)

interface

uses
   uCallbookBase;

type
   THamDBProvider = class(TCallbookProvider)
   protected
      function RequestUrl(const aEncodedCall: string): string; override;
      function ParseReply(const aReply: string): TCallbookRecord; override;
   end;

(* The JSON text of one hamdb reply into a NEW record the caller frees.  PURE:
   no network, no logging, never raises.  Empty text, text that is not JSON, a
   document of the wrong shape and a NOT_FOUND reply all give Found=False. *)
function ParseHamDBReply(const aJson: string): TCallbookRecord;

implementation

uses
   SysUtils, fpjson, uJSON, uCallbookRegistry;

const
   HAMDB_URL_PREFIX = 'https://api.hamdb.org/v1/';
   (* The application name the service asks to be told, fixed. *)
   HAMDB_APP_NAME   = 'TR4W';
   HAMDB_NOT_FOUND  = 'NOT_FOUND';
   HAMDB_OK         = 'OK';

(* One callsign field as text; the service's NOT_FOUND filler reads as ''. *)
function HamDBField(aObj: TJSONObject; const aName: string): string;
begin
   Result := Trim(JSONGetStr(aObj, aName, ''));
   if Result = HAMDB_NOT_FOUND then
      begin
      Result := '';
      end;
end;

function ParseHamDBReply(const aJson: string): TCallbookRecord;
var
   data:     TJSONData;
   hamdb:    TJSONData;
   messages: TJSONData;
   callsign: TJSONData;
   callObj:  TJSONObject;
begin
   Result := TCallbookRecord.Create;
   if Trim(aJson) = '' then
      begin
      Exit;
      end;

   data := nil;
   try
      try
         (* GetJSON RAISES on malformed input (see uJSON's header), and takes
            UTF8String: a JSON document is UTF-8 by definition. *)
         data := GetJSON(UTF8Encode(aJson));
         if not (data is TJSONObject) then
            begin
            Exit;
            end;
         hamdb := TJSONObject(data).GetValue('hamdb');
         if not (hamdb is TJSONObject) then
            begin
            Exit;
            end;
         messages := TJSONObject(hamdb).GetValue('messages');
         callsign := TJSONObject(hamdb).GetValue('callsign');
         if not ((messages is TJSONObject) and (callsign is TJSONObject)) then
            begin
            Exit;
            end;
         if HamDBField(TJSONObject(messages), 'status') <> HAMDB_OK then
            begin
            Exit;
            end;

         callObj := TJSONObject(callsign);
         Result.Call := HamDBField(callObj, 'call');
         if Result.Call = '' then
            begin
            Exit;
            end;
         Result.FirstName    := HamDBField(callObj, 'fname');
         Result.LastName     := HamDBField(callObj, 'name');
         Result.Grid         := HamDBField(callObj, 'grid');
         Result.Latitude     := HamDBField(callObj, 'lat');
         Result.Longitude    := HamDBField(callObj, 'lon');
         Result.State        := HamDBField(callObj, 'state');
         Result.Zip          := HamDBField(callObj, 'zip');
         Result.Country      := HamDBField(callObj, 'country');
         Result.LicenceClass := HamDBField(callObj, 'class');
         Result.Expires      := HamDBField(callObj, 'expires');
         Result.Found        := True;
      except
         on E: Exception do
            begin
            (* Not JSON.  Hand back an empty, not-found record. *)
            Result.Free;
            Result := TCallbookRecord.Create;
            end;
      end;
   finally
      data.Free;
   end;
end;

function THamDBProvider.RequestUrl(const aEncodedCall: string): string;
begin
   Result := HAMDB_URL_PREFIX + aEncodedCall + '/json/' + HAMDB_APP_NAME;
end;

function THamDBProvider.ParseReply(const aReply: string): TCallbookRecord;
begin
   Result := ParseHamDBReply(aReply);
end;

initialization
   RegisterCallbookProvider('hamdb', 'HamDB (hamdb.org)', False, THamDBProvider);
end.

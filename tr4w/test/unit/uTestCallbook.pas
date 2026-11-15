unit uTestCallbook;

(* THE CALLBOOK LOOKUP, OFFLINE (issue 321).

   Everything here runs without a network: the hamdb reply parser is a pure
   function, and the registry and the call encoding need no request.  The not-found
   body below is the one the live service returned on 2026-11-14 for a made-up
   call, byte for byte apart from whitespace. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCallbookTests = class(TTestCase)
   protected
      procedure TestParseFoundReply;
      procedure TestParseNotFoundReply;
      procedure TestParseGarbage;
      procedure TestParseEmptyAndWrongShape;
      procedure TestEncodeCall;
      procedure TestRegistryHasHamDB;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uCallbookBase, uCallbookRegistry, uCallbookHamDB;

const
   FOUND_REPLY =
      '{"hamdb":{"version":"1","callsign":{"call":"NY4I","class":"E",' +
      '"expires":"06/16/2032","status":"A","grid":"EL88pa","lat":"28.03",' +
      '"lon":"-82.72","fname":"THOMAS","mi":"M","name":"SCHAEFER","suffix":"",' +
      '"addr1":"1 Example St","addr2":"Clearwater","state":"FL","zip":"33761",' +
      '"country":"United States"},"messages":{"status":"OK"}}}';

   NOT_FOUND_REPLY =
      '{"hamdb":{"version":"1","callsign":{"call":"NOT_FOUND","class":"NOT_FOUND",' +
      '"expires":"NOT_FOUND","status":"NOT_FOUND","grid":"NOT_FOUND",' +
      '"lat":"NOT_FOUND","lon":"NOT_FOUND","fname":"NOT_FOUND","mi":"NOT_FOUND",' +
      '"name":"NOT_FOUND","suffix":"NOT_FOUND","addr1":"NOT_FOUND",' +
      '"addr2":"NOT_FOUND","state":"NOT_FOUND","zip":"NOT_FOUND",' +
      '"country":"NOT_FOUND"},"messages":{"status":"NOT_FOUND"}}}';

procedure TCallbookTests.TestParseFoundReply;
var
   rec: TCallbookRecord;
begin
   BeginTest('TestParseFoundReply');
   rec := ParseHamDBReply(FOUND_REPLY);
   try
      CheckTrue(rec.Found, 'an OK reply is found');
      CheckEquals('NY4I',          rec.Call,         'call');
      CheckEquals('THOMAS',        rec.FirstName,    'first name');
      CheckEquals('SCHAEFER',      rec.LastName,     'last name');
      CheckEquals('EL88pa',        rec.Grid,         'grid');
      CheckEquals('28.03',         rec.Latitude,     'latitude, as sent');
      CheckEquals('-82.72',        rec.Longitude,    'longitude, as sent');
      CheckEquals('FL',            rec.State,        'state');
      CheckEquals('33761',         rec.Zip,          'zip');
      CheckEquals('United States', rec.Country,      'country');
      CheckEquals('E',             rec.LicenceClass, 'licence class');
      CheckEquals('06/16/2032',    rec.Expires,      'expiry');
   finally
      rec.Free;
   end;
end;

procedure TCallbookTests.TestParseNotFoundReply;
var
   rec: TCallbookRecord;
begin
   BeginTest('TestParseNotFoundReply');
   rec := ParseHamDBReply(NOT_FOUND_REPLY);
   try
      CheckFalse(rec.Found, 'the live not-found reply is not found');
      CheckEquals('', rec.Call,      'NOT_FOUND filler is not a call');
      CheckEquals('', rec.FirstName, 'no first name');
      CheckEquals('', rec.Grid,      'no grid');
   finally
      rec.Free;
   end;
end;

procedure TCallbookTests.TestParseGarbage;
var
   rec: TCallbookRecord;
begin
   BeginTest('TestParseGarbage');
   (* The Apache 404 page hamdb answers a percent-encoded slash with. *)
   rec := ParseHamDBReply('<html><head><title>Object not found!</title></head></html>');
   try
      CheckFalse(rec.Found, 'HTML is not found, and does not raise');
   finally
      rec.Free;
   end;
   rec := ParseHamDBReply('{"hamdb":{"callsign":');
   try
      CheckFalse(rec.Found, 'truncated JSON is not found, and does not raise');
   finally
      rec.Free;
   end;
end;

procedure TCallbookTests.TestParseEmptyAndWrongShape;
var
   rec: TCallbookRecord;
begin
   BeginTest('TestParseEmptyAndWrongShape');
   rec := ParseHamDBReply('');
   try
      CheckFalse(rec.Found, 'empty text');
   finally
      rec.Free;
   end;
   rec := ParseHamDBReply('[1,2,3]');
   try
      CheckFalse(rec.Found, 'a JSON array');
   finally
      rec.Free;
   end;
   rec := ParseHamDBReply('{"hamdb":{"messages":{"status":"OK"}}}');
   try
      CheckFalse(rec.Found, 'OK with no callsign object');
   finally
      rec.Free;
   end;
end;

procedure TCallbookTests.TestEncodeCall;
begin
   BeginTest('TestEncodeCall');
   CheckEquals('NY4I',     EncodeCallbookCall('ny4i'),      'upper-cased');
   CheckEquals('NY4I',     EncodeCallbookCall('  NY4I '),   'trimmed');
   CheckEquals('W1AW%2F4', EncodeCallbookCall('W1AW/4'),    'a slash is percent-encoded');
end;

procedure TCallbookTests.TestRegistryHasHamDB;
var
   registration: TCallbookRegistration;
   provider:     TCallbookProvider;
begin
   BeginTest('TestRegistryHasHamDB');
   CheckTrue(FindCallbookRegistration('hamdb', registration), 'hamdb is registered');
   CheckFalse(registration.NeedsLogin, 'hamdb needs no login');
   provider := CreateCallbookProvider('hamdb');
   try
      CheckEquals('hamdb', provider.Id, 'the factory stamps the id');
   finally
      provider.Free;
   end;
end;

procedure TCallbookTests.RunAllTests;
begin
   TestParseFoundReply;
   TestParseNotFoundReply;
   TestParseGarbage;
   TestParseEmptyAndWrongShape;
   TestEncodeCall;
   TestRegistryHasHamDB;
end;

end.

{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
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
unit uUDPBroadcastConfig;
{$I tr4w.inc}

{
  The UDP broadcast settings, as a value that can be stored, compared and
  tested -- one of the tenants of settings\tr4w.json.

  WHY THESE LEFT THE COMMAND LIST.  Fourteen rows in a flat alphabetical list of
  500 read as fourteen unrelated station settings.  They are not: they are a set
  of DESTINATIONS, each one a stream plus somewhere to send it.  The list could
  not express that, and could not stop an operator setting a port for a stream
  they had not enabled (NY4I 2026-08-08).

  A LIST, NOT ONE ADDRESS WITH A PORT PER STREAM.  The legacy shape allowed
  exactly one listener per kind of data, which is wrong for a station running,
  say, a logger and a score server and a second screen (NY4I 2026-08-08).  The
  old shape is the degenerate case: seeding an existing ini produces one
  destination per enabled stream, all sharing the one address it held.

  A DESTINATION CARRIES A SET OF STREAMS, not one.  The row an operator thinks
  in is an ENDPOINT -- "my N1MM bridge at 10.0.0.5:12060" -- and what varies is
  which kinds of data it wants.  One row per stream would list that same
  endpoint six times and make "change its address" six edits, five of which can
  be forgotten.  This is also the shape of NY4I's TR4QT panel.  Note that it
  still keeps a port PER ROW rather than per station, which the flat host:port
  list in TR4QT cannot do: N1MM's own documentation puts RadioInfo on 12060 and
  ContactInfo on 12061, so one endpoint genuinely needs two rows.

  THE PER-STREAM ENABLE FLAG IS GONE, and that is the point rather than a side
  effect.  "Is this stream on" and "where does it go" were two facts free to
  disagree -- an operator could have CONTACT=FALSE and a contact port carefully
  set, which means nothing.  A stream is on when something is listening: no
  destination carrying it, no broadcast.

  THE MASTER ENABLE IS NOT THAT FLAG COMING BACK.  It answers a question the
  destination list cannot: "stop broadcasting for now, without me losing the
  four endpoints I spent ten minutes typing."  It is one switch over the whole
  facility, it cannot disagree with any individual destination, and it is the
  only thing standing between an operator and deleting rows to go quiet.

  RTL ONLY, deliberately -- uJSON, SysUtils, IniFiles and nothing of
  TR4W's.  That is what lets the whole thing be unit-tested without booting the
  application's globals, exactly as the radio and keyer stores are.  Pushing the
  values into those globals is uUDPBroadcastApply's job, and it is the only unit
  here that needs the program.

  THE DEFAULTS ARE NOT INVENTED.  They are the compiled-in initialisers from
  LOGSTUFF.PAS (ports 12060, rotor 12040, address 127.0.0.1) so that a station
  with no udp section in its JSON behaves exactly as one with no UDP lines in
  its ini always did.

  WHAT IS DELIBERATELY ABSENT.  'UDP BROADCAST PORT' is not here.  LOGSTUFF.PAS
  declares it "Kept for backward compatibility - no longer used", and it has no
  remaining reader anywhere in the project.  (Its last references were in
  LOGSUBS2~.PAS, an IDE backup copy that was never in the project and has since
  been deleted from the repo.)  Superseded by the per-stream ports below; carrying it into a
  new format would have given a dead setting a second life and a checkbox.

  APP INFO IS PRESENT BUT UNIMPLEMENTED.  Nothing in TR4W sends an app-info
  broadcast today -- the enable and its port have no reader.  Kept because the
  feature is unfinished rather than withdrawn (NY4I 2026-08-08); the UI is
  expected to say so rather than offering a control that silently does nothing.
}

interface

uses
   SysUtils,
   Classes,
   Generics.Collections,
   IniFiles,
   uJSON;

const
   // From LOGSTUFF.PAS's initialisers -- see the unit header.
   UDP_DEFAULT_ADDRESS    = '127.0.0.1';
   UDP_DEFAULT_PORT       = 12060;
   UDP_DEFAULT_ROTORPORT  = 12040;

   // The ini keys these were read from, kept for SEEDING only.  Spelled here
   // rather than imported from uCFG so this unit stays free of the command
   // table -- and pinned by a test, because a typo would silently seed a
   // default over an operator's real setting.
   INIKEY_ADDRESS       = 'UDP BROADCAST ADDRESS';
   INIKEY_APPINFO       = 'UDP BROADCAST APP INFO';
   INIKEY_CONTACT       = 'UDP BROADCAST CONTACT INFO';
   INIKEY_RADIO         = 'UDP BROADCAST RADIO INFO';
   INIKEY_ROTOR         = 'UDP BROADCAST ROTOR';
   INIKEY_SCORE         = 'UDP BROADCAST SCORE';
   INIKEY_LOOKUP        = 'UDP BROADCAST LOOKUP INFO';
   INIKEY_ALLQSOS       = 'UDP BROADCAST ALL QSOS';
   INIKEY_PORTAPP       = 'UDP BROADCAST PORT APP INFO';
   INIKEY_PORTCONTACT   = 'UDP BROADCAST PORT CONTACT';
   INIKEY_PORTRADIO     = 'UDP BROADCAST PORT RADIO';
   INIKEY_PORTSCORE     = 'UDP BROADCAST PORT SCORE';
   INIKEY_PORTLOOKUP    = 'UDP BROADCAST PORT LOOKUP';
   INIKEY_ROTORPORT     = 'UDP BROADCAST ROTOR PORT';

   // The section every one of them lives in: they are config COMMANDS, so they
   // sit with the rest of them rather than in a section of their own.
   INISECTION_COMMANDS  = 'COMMANDS';

type
   // One member per broadcast STREAM -- the kind of data, not where it goes.
   // Declared HERE rather than on the broadcaster because the config is the
   // lower unit and both need it.
   TUDPStream = (usAppInfo, usContact, usScore, usRadio, usRotor, usLookup);
   TUDPStreams = set of TUDPStream;

   // One place data is sent -- an address and a port -- and which streams it
   // wants.  A stream may be carried by several destinations, and a destination
   // may carry several streams.
   TUDPDestination = class
   private
      FStreams: TUDPStreams;
      FAddress: string;
      FPort: integer;
   public
      constructor Create(const aAddress: string;
                         const aPort: integer;
                         const aStreams: TUDPStreams);
      function Clone: TUDPDestination;
      function SameAs(const aOther: TUDPDestination): boolean;

      // Copies the VALUES onto an existing object, leaving its identity alone.
      // That is what lets the editor work on a clone and then write the result
      // back: the config's list still holds the same object, so nothing that
      // referenced it is left pointing at a freed one.
      procedure Assign(const aSource: TUDPDestination);

      // Does this endpoint want that kind of data?
      function Carries(const aStream: TUDPStream): boolean;

      // Adds or removes one stream, so a checkbox does not have to do set
      // arithmetic at the call site.
      procedure SetStream(const aStream: TUDPStream; const aWanted: boolean);

      property Streams: TUDPStreams read FStreams write FStreams;
      property Address: string      read FAddress write FAddress;
      property Port: integer        read FPort    write FPort;
   end;

   TUDPBroadcastConfig = class
   private
      FDestinations: TObjectList<TUDPDestination>;
      FAllQSOs: boolean;
      FEnabled: boolean;
      function GetDestination(const aIndex: integer): TUDPDestination;
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;
      procedure Assign(const aSource: TUDPBroadcastConfig);
      function  Clone: TUDPBroadcastConfig;
      function  SameAs(const aOther: TUDPBroadcastConfig): boolean;

      // Adds a place to send.  Returns the destination so a caller can hold on
      // to it; the config owns it.
      function  AddDestination(const aAddress: string;
                               const aPort: integer;
                               const aStreams: TUDPStreams): TUDPDestination;
      procedure RemoveDestination(const aIndex: integer);

      // The destination at that address and port, or nil.  Endpoint identity is
      // (address, port) -- which is why two rows sharing one is a mistake
      // Validate refuses rather than a duplicate send nobody notices.
      function  FindDestination(const aAddress: string;
                                const aPort: integer): TUDPDestination;

      function  DestinationCount: integer;
      function  CountFor(const aStream: TUDPStream): integer;

      // Refuses what cannot work rather than letting it reach a socket: a port
      // outside 1..65535 and an empty address are configuration mistakes that
      // would otherwise surface as a broadcast that silently goes nowhere.
      function  Validate(out aError: string): boolean;

      // Reads whatever the operator's ini already holds and turns it into
      // destinations -- one per stream that was switched on, all sharing the
      // single address the ini had room for.  A stream that was OFF produces no
      // destination, which is the same thing said in the new shape.
      procedure SeedFromLegacyIni(const aIni: TCustomIniFile);

      function  ToJSON: TJSONObject;
      procedure FromJSON(const aObj: TJSONObject);

      property Destination[const aIndex: integer]: TUDPDestination read GetDestination;
      property AllQSOs: boolean read FAllQSOs write FAllQSOs;

      // The master switch.  False silences every stream while leaving the
      // destinations exactly as the operator typed them.  Defaults TRUE so that
      // a file written before it existed -- or an ini seeded into one -- keeps
      // behaving as it did.
      property Enabled: boolean read FEnabled write FEnabled;
   end;

// The stream's name as it is written to JSON.  A NAME, not the ordinal: the
// enum can be reordered or extended without silently repointing every stored
// destination at a different kind of data.
function UDPStreamName(const aStream: TUDPStream): string;
function UDPStreamFromName(const aName: string; out aStream: TUDPStream): boolean;

implementation

const
   // JSON member names.  Lower camel, matching the radio and keyer sections.
   J_ALLQSOS      = 'allQSOs';
   J_ENABLED      = 'enabled';
   J_DESTINATIONS = 'destinations';
   J_STREAMS      = 'streams';
   J_ADDRESS      = 'address';
   J_PORT         = 'port';

   // The member a destination used to store when it carried exactly one stream.
   // Still READ, never written: a settings file from the first cut of this
   // feature must not lose its destinations, and dropping them would look like
   // "TR4W forgot my UDP settings" rather than a format change.
   J_STREAM_LEGACY = 'stream';

   // The stored spelling of each stream.  Written out rather than derived from
   // the enum, so renaming a member in code cannot silently orphan every stored
   // destination that named it.
   STREAMNAMES: array[TUDPStream] of string =
      ('appInfo', 'contact', 'score', 'radio', 'rotor', 'lookup');

function UDPStreamName(const aStream: TUDPStream): string;
begin
   Result := STREAMNAMES[aStream];
end;

function UDPStreamFromName(const aName: string; out aStream: TUDPStream): boolean;
var
   st: TUDPStream;
begin
   Result := False;
   aStream := usContact;
   for st := Low(TUDPStream) to High(TUDPStream) do
      begin
      if SameText(Trim(aName), STREAMNAMES[st]) then
         begin
         aStream := st;
         Result  := True;
         Exit;
         end;
      end;
end;

{ ------------------------------------------------------- TUDPDestination -- }

constructor TUDPDestination.Create(const aAddress: string;
                                   const aPort: integer;
                                   const aStreams: TUDPStreams);
begin
   inherited Create;
   FAddress := aAddress;
   FPort    := aPort;
   FStreams := aStreams;
end;

function TUDPDestination.Clone: TUDPDestination;
begin
   Result := TUDPDestination.Create(FAddress, FPort, FStreams);
end;

function TUDPDestination.SameAs(const aOther: TUDPDestination): boolean;
begin
   Result := (aOther <> nil)                     and
             SameText(FAddress, aOther.FAddress) and
             (FPort = aOther.FPort)              and
             (FStreams = aOther.FStreams);
end;

procedure TUDPDestination.Assign(const aSource: TUDPDestination);
begin
   if aSource = nil then
      begin
      Exit;
      end;
   FAddress := aSource.FAddress;
   FPort    := aSource.FPort;
   FStreams := aSource.FStreams;
end;

function TUDPDestination.Carries(const aStream: TUDPStream): boolean;
begin
   Result := aStream in FStreams;
end;

procedure TUDPDestination.SetStream(const aStream: TUDPStream; const aWanted: boolean);
begin
   if aWanted then
      begin
      Include(FStreams, aStream);
      end
   else
      begin
      Exclude(FStreams, aStream);
      end;
end;

{ ---------------------------------------------------- TUDPBroadcastConfig - }

constructor TUDPBroadcastConfig.Create;
begin
   inherited Create;
   FDestinations := TObjectList<TUDPDestination>.Create(True);   // owns them
   FAllQSOs := False;
   FEnabled := True;    // see the Enabled property -- absence must not silence
end;

destructor TUDPBroadcastConfig.Destroy;
begin
   FDestinations.Free;
   inherited Destroy;
end;

procedure TUDPBroadcastConfig.Clear;
begin
   FDestinations.Clear;
   FAllQSOs := False;
   // Back to the constructed state, master switch included: "clear" means an
   // empty configuration, and an empty one broadcasts nothing anyway because
   // there is nowhere to send.
   FEnabled := True;
end;

function TUDPBroadcastConfig.GetDestination(const aIndex: integer): TUDPDestination;
begin
   Result := FDestinations[aIndex];
end;

function TUDPBroadcastConfig.DestinationCount: integer;
begin
   Result := FDestinations.Count;
end;

function TUDPBroadcastConfig.CountFor(const aStream: TUDPStream): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to FDestinations.Count - 1 do
      begin
      if FDestinations[i].Carries(aStream) then
         begin
         Inc(Result);
         end;
      end;
end;

function TUDPBroadcastConfig.AddDestination(const aAddress: string;
                                            const aPort: integer;
                                            const aStreams: TUDPStreams): TUDPDestination;
begin
   Result := TUDPDestination.Create(aAddress, aPort, aStreams);
   FDestinations.Add(Result);
end;

function TUDPBroadcastConfig.FindDestination(const aAddress: string;
                                             const aPort: integer): TUDPDestination;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to FDestinations.Count - 1 do
      begin
      if SameText(Trim(FDestinations[i].Address), Trim(aAddress)) and
         (FDestinations[i].Port = aPort) then
         begin
         Result := FDestinations[i];
         Exit;
         end;
      end;
end;

procedure TUDPBroadcastConfig.RemoveDestination(const aIndex: integer);
begin
   if (aIndex >= 0) and (aIndex < FDestinations.Count) then
      begin
      FDestinations.Delete(aIndex);
      end;
end;

procedure TUDPBroadcastConfig.Assign(const aSource: TUDPBroadcastConfig);
var
   i: integer;
begin
   if aSource = nil then
      begin
      Exit;
      end;

   // DEEP: the destinations are objects, and a shallow copy would leave two
   // configs sharing them -- so an edit in the dialog would reach into the
   // settings a send is already using, which is the whole thing the
   // broadcaster's copy is meant to prevent.
   FDestinations.Clear;
   for i := 0 to aSource.FDestinations.Count - 1 do
      begin
      FDestinations.Add(aSource.FDestinations[i].Clone);
      end;
   FAllQSOs := aSource.FAllQSOs;
   FEnabled := aSource.FEnabled;
end;

function TUDPBroadcastConfig.Clone: TUDPBroadcastConfig;
begin
   Result := TUDPBroadcastConfig.Create;
   Result.Assign(Self);
end;

function TUDPBroadcastConfig.SameAs(const aOther: TUDPBroadcastConfig): boolean;
var
   i: integer;
begin
   Result := False;
   if aOther = nil then
      begin
      Exit;
      end;
   if FAllQSOs <> aOther.FAllQSOs then
      begin
      Exit;
      end;
   if FEnabled <> aOther.FEnabled then
      begin
      Exit;
      end;
   if FDestinations.Count <> aOther.FDestinations.Count then
      begin
      Exit;
      end;

   // ORDER-SENSITIVE on purpose: the list is what the operator sees, and two
   // configs listing the same destinations in a different order are not the
   // same document even though they would behave alike.
   for i := 0 to FDestinations.Count - 1 do
      begin
      if not FDestinations[i].SameAs(aOther.FDestinations[i]) then
         begin
         Exit;
         end;
      end;
   Result := True;
end;

function TUDPBroadcastConfig.Validate(out aError: string): boolean;
var
   i, j: integer;
   d: TUDPDestination;
begin
   aError := '';
   Result := False;

   for i := 0 to FDestinations.Count - 1 do
      begin
      d := FDestinations[i];

      // Every message names WHICH row, by position and by endpoint.  A
      // destination is no longer identified by the one stream it carried, and
      // "a port is out of range" in a list of four is not actionable.
      if Trim(d.Address) = '' then
         begin
         aError := Format('Destination %d has no address.', [i + 1]);
         Exit;
         end;

      // The legacy global was a string[255]; anything longer was truncated on
      // the way in, which is a silent change of destination.
      if Length(d.Address) > 255 then
         begin
         aError := Format('Destination %d has an address longer than 255 characters.',
                          [i + 1]);
         Exit;
         end;

      if (d.Port < 1) or (d.Port > 65535) then
         begin
         aError := Format('Destination %d (%s) has port %d; it must be between 1 and 65535.',
                          [i + 1, Trim(d.Address), d.Port]);
         Exit;
         end;

      // A row carrying nothing is NOT the same as "switched off": it is an
      // address and a port that will never be sent anything, and it reads on
      // the panel as a destination that is configured.  Going quiet is what the
      // master switch is for.
      if d.Streams = [] then
         begin
         aError := Format('Destination %d (%s:%d) has no data selected. ' +
                          'Choose at least one kind of data, or remove it.',
                          [i + 1, Trim(d.Address), d.Port]);
         Exit;
         end;

      // The same endpoint twice sends everything it carries twice.  A remote
      // logger seeing duplicate QSOs is a support call that looks like a TR4W
      // bug, so refuse it here rather than at the socket.
      for j := 0 to i - 1 do
         begin
         if SameText(Trim(FDestinations[j].Address), Trim(d.Address)) and
            (FDestinations[j].Port = d.Port) then
            begin
            aError := Format('%s:%d is listed twice (destinations %d and %d). ' +
                             'Put every kind of data it should receive on one of them.',
                             [Trim(d.Address), d.Port, j + 1, i + 1]);
            Exit;
            end;
         end;
      end;

   Result := True;
end;

procedure TUDPBroadcastConfig.SeedFromLegacyIni(const aIni: TCustomIniFile);
var
   address: string;

   // NOT TIniFile.ReadBool.  That parses '0' and '1'; TR4W's config writes the
   // CFGCA vocabulary, 'TRUE' and 'FALSE', so ReadBool silently returned the
   // DEFAULT for every boolean and an operator's enabled streams would have
   // come back switched off.  Caught by the seeding test, not the compiler.
   function CFGBool(const aKey: string): boolean;
   var
      raw: string;
   begin
      raw := Trim(aIni.ReadString(INISECTION_COMMANDS, aKey, ''));
      Result := SameText(raw, 'TRUE') or (raw = '1');
   end;

   procedure SeedStream(const aStream: TUDPStream;
                        const aEnableKey, aPortKey: string;
                        const aDefaultPort: integer);
   var
      port: integer;
      dest: TUDPDestination;
   begin
      // A stream that was OFF produces NO destination.  That is the same fact
      // said in the new shape, and it is why the per-stream flag does not
      // survive.
      if not CFGBool(aEnableKey) then
         begin
         Exit;
         end;

      // An ABSENT port key keeps the compiled-in default rather than reading as
      // 0: most stations never wrote them and were running on the defaults.
      port := aIni.ReadInteger(INISECTION_COMMANDS, aPortKey, aDefaultPort);

      // MERGED onto the endpoint rather than one row per stream.  The ini held
      // ONE address, so a station with five streams on the default port has one
      // listener wanting five kinds of data -- and listing it five times would
      // be the first thing the operator had to tidy up by hand.  It also keeps
      // seeding within what Validate accepts, which refuses the same address
      // and port twice.
      dest := FindDestination(address, port);
      if dest = nil then
         begin
         dest := AddDestination(address, port, []);
         end;
      dest.SetStream(aStream, True);
   end;

begin
   if aIni = nil then
      begin
      Exit;
      end;

   Clear;

   // The ini had room for ONE address, shared by every stream.
   address := Trim(aIni.ReadString(INISECTION_COMMANDS, INIKEY_ADDRESS, UDP_DEFAULT_ADDRESS));
   if address = '' then
      begin
      address := UDP_DEFAULT_ADDRESS;
      end;

   SeedStream(usAppInfo, INIKEY_APPINFO, INIKEY_PORTAPP,     UDP_DEFAULT_PORT);
   SeedStream(usContact, INIKEY_CONTACT, INIKEY_PORTCONTACT, UDP_DEFAULT_PORT);
   SeedStream(usScore,   INIKEY_SCORE,   INIKEY_PORTSCORE,   UDP_DEFAULT_PORT);
   SeedStream(usRadio,   INIKEY_RADIO,   INIKEY_PORTRADIO,   UDP_DEFAULT_PORT);
   SeedStream(usRotor,   INIKEY_ROTOR,   INIKEY_ROTORPORT,   UDP_DEFAULT_ROTORPORT);
   SeedStream(usLookup,  INIKEY_LOOKUP,  INIKEY_PORTLOOKUP,  UDP_DEFAULT_PORT);

   FAllQSOs := CFGBool(INIKEY_ALLQSOS);
end;

function TUDPBroadcastConfig.ToJSON: TJSONObject;
var
   arr: TJSONArray;
   streams: TJSONArray;
   obj: TJSONObject;
   st: TUDPStream;
   i: integer;
begin
   Result := TJSONObject.Create;
   Result.AddPair(J_ALLQSOS, TJSONBool.Create(FAllQSOs));
   Result.AddPair(J_ENABLED, TJSONBool.Create(FEnabled));

   arr := TJSONArray.Create;
   for i := 0 to FDestinations.Count - 1 do
      begin
      obj := TJSONObject.Create;
      obj.AddPair(J_ADDRESS, FDestinations[i].Address);
      obj.AddPair(J_PORT,    TJSONNumber.Create(FDestinations[i].Port));

      // Written in ENUM order, not the order they were ticked, so a file does
      // not churn in git every time the panel rebuilds a row.
      streams := TJSONArray.Create;
      for st := Low(TUDPStream) to High(TUDPStream) do
         begin
         if FDestinations[i].Carries(st) then
            begin
            streams.Add(UDPStreamName(st));
            end;
         end;
      obj.AddPair(J_STREAMS, streams);

      arr.AddElement(obj);
      end;
   Result.AddPair(J_DESTINATIONS, arr);
end;

// The streams a stored destination asks for.  Understands BOTH spellings: the
// 'streams' array written today, and the single 'stream' member written by the
// first cut of this feature.  Returns [] when it can make out neither, which
// the caller treats as "skip this row" rather than "send it everything".
function StreamsFromJSON(const aObj: TJSONObject): TUDPStreams;
var
   arr: TJSONValue;
   st: TUDPStream;
   i: integer;
begin
   Result := [];

   arr := aObj.FindValue(J_STREAMS);
   if arr is TJSONArray then
      begin
      for i := 0 to TJSONArray(arr).Count - 1 do
         begin
         // A name this build does not know is SKIPPED, not guessed at: sending
         // contacts to something expecting scores is worse than not sending.
         if UDPStreamFromName(JSONText(TJSONArray(arr).Items[i]), st) then
            begin
            Include(Result, st);
            end;
         end;
      Exit;
      end;

   if UDPStreamFromName(JSONGetStr(aObj, J_STREAM_LEGACY, ''), st) then
      begin
      Include(Result, st);
      end;
end;

procedure TUDPBroadcastConfig.FromJSON(const aObj: TJSONObject);
var
   arr: TJSONValue;
   item: TJSONValue;
   obj: TJSONObject;
   dest: TUDPDestination;
   streams: TUDPStreams;
   address: string;
   port: integer;
   i: integer;
   v: TJSONValue;
begin
   if aObj = nil then
      begin
      Exit;
      end;

   v := aObj.FindValue(J_ALLQSOS);
   if v is TJSONBool then
      begin
      FAllQSOs := TJSONBool(v).AsBoolean;
      end;

   // ABSENT means a file written before the master switch existed.  It must
   // read as ON: the alternative is that upgrading TR4W silently stops every
   // broadcast the operator had working.
   v := aObj.FindValue(J_ENABLED);
   if v is TJSONBool then
      begin
      FEnabled := TJSONBool(v).AsBoolean;
      end;

   arr := aObj.FindValue(J_DESTINATIONS);
   if not (arr is TJSONArray) then
      begin
      // No destinations MEMBER at all leaves whatever is loaded alone; an empty
      // ARRAY below is a different statement and does clear them.
      Exit;
      end;

   FDestinations.Clear;
   for i := 0 to TJSONArray(arr).Count - 1 do
      begin
      item := TJSONArray(arr).Items[i];
      if not (item is TJSONObject) then
         begin
         Continue;
         end;
      obj := TJSONObject(item);

      // A row asking for nothing this build understands is dropped rather than
      // kept as an endpoint that never sends -- which Validate would then
      // refuse, leaving the operator unable to save a file they did not write.
      streams := StreamsFromJSON(obj);
      if streams = [] then
         begin
         Continue;
         end;

      address := JSONGetStr(obj, J_ADDRESS, UDP_DEFAULT_ADDRESS);
      port    := JSONGetInt(obj, J_PORT, UDP_DEFAULT_PORT);

      // MERGED by endpoint.  A file in the first cut of this format stored one
      // row per stream, so the same address and port appears up to six times --
      // and rows that are duplicates by the current rules would load, fail
      // Validate, and leave the operator unable to save a file they did not
      // write.  Reading is also then idempotent.
      dest := FindDestination(address, port);
      if dest = nil then
         begin
         AddDestination(address, port, streams);
         end
      else
         begin
         dest.Streams := dest.Streams + streams;
         end;
      end;
end;

end.

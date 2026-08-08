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

  THE ENABLE FLAG IS GONE, and that is the point rather than a side effect.
  "Is this stream on" and "where does it go" were two facts free to disagree --
  an operator could have CONTACT=FALSE and a contact port carefully set, which
  means nothing.  A stream is on when something is listening: no destinations,
  no broadcast.

  RTL ONLY, deliberately -- System.JSON, SysUtils, IniFiles and nothing of
  TR4W's.  That is what lets the whole thing be unit-tested without booting the
  application's globals, exactly as the radio and keyer stores are.  Pushing the
  values into those globals is uUDPBroadcastApply's job, and it is the only unit
  here that needs the program.

  THE DEFAULTS ARE NOT INVENTED.  They are the compiled-in initialisers from
  LOGSTUFF.PAS (ports 12060, rotor 12040, address 127.0.0.1) so that a station
  with no udp section in its JSON behaves exactly as one with no UDP lines in
  its ini always did.

  WHAT IS DELIBERATELY ABSENT.  'UDP BROADCAST PORT' is not here.  LOGSTUFF.PAS
  declares it "Kept for backward compatibility - no longer used", and its only
  remaining references are in LOGSUBS2~.PAS, which is editor debris and is not
  in the project.  Superseded by the per-stream ports below; carrying it into a
  new format would have given a dead setting a second life and a checkbox.

  APP INFO IS PRESENT BUT UNIMPLEMENTED.  Nothing in TR4W sends an app-info
  broadcast today -- the enable and its port have no reader.  Kept because the
  feature is unfinished rather than withdrawn (NY4I 2026-08-08); the UI is
  expected to say so rather than offering a control that silently does nothing.
}

interface

uses
   System.SysUtils,
   System.Classes,
   System.Generics.Collections,
   System.IniFiles,
   System.JSON;

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

   // Somewhere one stream is sent.  A stream may have several.
   TUDPDestination = class
   private
      FStream: TUDPStream;
      FAddress: string;
      FPort: integer;
   public
      constructor Create(const aStream: TUDPStream;
                         const aAddress: string;
                         const aPort: integer);
      function Clone: TUDPDestination;
      function SameAs(const aOther: TUDPDestination): boolean;

      property Stream: TUDPStream read FStream  write FStream;
      property Address: string    read FAddress write FAddress;
      property Port: integer      read FPort    write FPort;
   end;

   TUDPBroadcastConfig = class
   private
      FDestinations: TObjectList<TUDPDestination>;
      FAllQSOs: boolean;
      function GetDestination(const aIndex: integer): TUDPDestination;
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;
      procedure Assign(const aSource: TUDPBroadcastConfig);
      function  Clone: TUDPBroadcastConfig;
      function  SameAs(const aOther: TUDPBroadcastConfig): boolean;

      // Adds a place to send one stream.  Returns the destination so a caller
      // can hold on to it; the config owns it.
      function  AddDestination(const aStream: TUDPStream;
                               const aAddress: string;
                               const aPort: integer): TUDPDestination;
      procedure RemoveDestination(const aIndex: integer);

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
   J_DESTINATIONS = 'destinations';
   J_STREAM       = 'stream';
   J_ADDRESS      = 'address';
   J_PORT         = 'port';

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

constructor TUDPDestination.Create(const aStream: TUDPStream;
                                   const aAddress: string;
                                   const aPort: integer);
begin
   inherited Create;
   FStream  := aStream;
   FAddress := aAddress;
   FPort    := aPort;
end;

function TUDPDestination.Clone: TUDPDestination;
begin
   Result := TUDPDestination.Create(FStream, FAddress, FPort);
end;

function TUDPDestination.SameAs(const aOther: TUDPDestination): boolean;
begin
   Result := (aOther <> nil)                     and
             (FStream = aOther.FStream)          and
             SameText(FAddress, aOther.FAddress) and
             (FPort = aOther.FPort);
end;

{ ---------------------------------------------------- TUDPBroadcastConfig - }

constructor TUDPBroadcastConfig.Create;
begin
   inherited Create;
   FDestinations := TObjectList<TUDPDestination>.Create(True);   // owns them
   FAllQSOs := False;
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
      if FDestinations[i].Stream = aStream then
         begin
         Inc(Result);
         end;
      end;
end;

function TUDPBroadcastConfig.AddDestination(const aStream: TUDPStream;
                                            const aAddress: string;
                                            const aPort: integer): TUDPDestination;
begin
   Result := TUDPDestination.Create(aStream, aAddress, aPort);
   FDestinations.Add(Result);
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
   i: integer;
   d: TUDPDestination;
begin
   aError := '';
   Result := False;

   for i := 0 to FDestinations.Count - 1 do
      begin
      d := FDestinations[i];

      if Trim(d.Address) = '' then
         begin
         aError := Format('The %s destination has no address.',
                          [UDPStreamName(d.Stream)]);
         Exit;
         end;

      // The legacy global was a string[255]; anything longer was truncated on
      // the way in, which is a silent change of destination.
      if Length(d.Address) > 255 then
         begin
         aError := Format('The %s destination address is longer than 255 characters.',
                          [UDPStreamName(d.Stream)]);
         Exit;
         end;

      if (d.Port < 1) or (d.Port > 65535) then
         begin
         aError := Format('The %s destination port must be between 1 and 65535 (it is %d).',
                          [UDPStreamName(d.Stream), d.Port]);
         Exit;
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
   begin
      // A stream that was OFF produces NO destination.  That is the same fact
      // said in the new shape, and it is why the enable flag does not survive.
      if not CFGBool(aEnableKey) then
         begin
         Exit;
         end;
      // An ABSENT port key keeps the compiled-in default rather than reading as
      // 0: most stations never wrote them and were running on the defaults.
      AddDestination(aStream, address,
                     aIni.ReadInteger(INISECTION_COMMANDS, aPortKey, aDefaultPort));
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
   obj: TJSONObject;
   i: integer;
begin
   Result := TJSONObject.Create;
   Result.AddPair(J_ALLQSOS, TJSONBool.Create(FAllQSOs));

   arr := TJSONArray.Create;
   for i := 0 to FDestinations.Count - 1 do
      begin
      obj := TJSONObject.Create;
      obj.AddPair(J_STREAM,  UDPStreamName(FDestinations[i].Stream));
      obj.AddPair(J_ADDRESS, FDestinations[i].Address);
      obj.AddPair(J_PORT,    TJSONNumber.Create(FDestinations[i].Port));
      arr.AddElement(obj);
      end;
   Result.AddPair(J_DESTINATIONS, arr);
end;

procedure TUDPBroadcastConfig.FromJSON(const aObj: TJSONObject);
var
   arr: TJSONValue;
   item: TJSONValue;
   obj: TJSONObject;
   st: TUDPStream;
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

      // A destination naming a stream this build does not know is SKIPPED, not
      // guessed at.  Sending contacts to something expecting scores is worse
      // than not sending them.
      if not UDPStreamFromName(obj.GetValue<string>(J_STREAM, ''), st) then
         begin
         Continue;
         end;

      AddDestination(st,
                     obj.GetValue<string>(J_ADDRESS, UDP_DEFAULT_ADDRESS),
                     obj.GetValue<integer>(J_PORT, UDP_DEFAULT_PORT));
      end;
end;

end.

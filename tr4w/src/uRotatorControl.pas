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
unit uRotatorControl;
{$I tr4w.inc}

{
  WHICH ROTATOR TURNS, and how the bytes get out.

  The facade between TR4W and the rotator factory, and it lives in src/ rather
  than inside LOGSTUFF on purpose: src/trdos is proven contest logic, and the
  house rule is to add units beside it rather than grow it.  LOGSTUFF's
  RotorControl becomes a one-line delegation to here -- the same strangler shape
  the radio factory and the CW keyer factory used, where the old entry point
  survives as a name while everything behind it moves.

  TWO THINGS THIS OWNS that the old `case ActiveRotatorType of` could not:

  SELECTION BY BAND.  NY4I: "I could see a case of defining a band to a rotator
  and when we tell the program to turn the rotator for a contact on 20m, it
  knows to turn the Orion rotator but on 40 meters, it turns the Yaesu rotator."
  A rotator definition claims bands; a blank claim means every band.  With one
  rotator defined -- which is nearly everybody -- the answer is always that one,
  and no operator has to learn the feature exists.

  TRANSPORT.  A driver builds bytes and knows nothing about where they go.  Here
  is where a serial rotator's frame reaches the port handle and PstRotator's
  reaches a UDP socket.  That split is what let every frame be unit-tested with
  no hardware.

  MIGRATION, and why nothing breaks for an operator who has not opened the new
  page.  If the library is empty, Configure SEEDS one rotator from the legacy
  ROTATOR TYPE and ROTATOR PORT settings.  So an existing station keeps working
  unchanged, the legacy `case` can be deleted rather than kept as a fallback,
  and there is exactly one code path from the start -- which is the thing that
  makes the old path safe to remove instead of leaving two to drift.
}

interface

uses
   SysUtils,
   Generics.Collections,
   uRotatorBase,
   uRadioConfigStore;

{ Rebuild the live rotators from the library.  Called at startup and whenever
  the settings are saved.  Seeds from the legacy settings when the library is
  empty -- see the unit header. }
procedure ConfigureRotators(const aStore: TRadioConfigStore);

{ Point whichever rotator serves aBandName.  aBandName is the
  BandStringsArrayWithOutSpaces spelling ('20', '40'); blank means "do not
  care", which matches every rotator that has not claimed specific bands. }
procedure TurnRotator(const aHeading: integer; const aBandName: string);

{ How many rotators are live.  For the log and for a test. }
function LiveRotatorCount: integer;

implementation

uses
   VC,
   Tree,
   utils_file,   // sWriteFile
   LOGSTUFF,     // SendPSTRotorCommand -- the UDP socket, reused not rebuilt
   LOGK1EA,      // CPUKeyer.SerialPortConfigured_Handle -- the open port handles
   LOGWIND,      // RotatorType / RotatorTypeSA, for the legacy seed
   uRotatorRegistry,
   MainUnit;     // logger

type
   { A live rotator: the driver, plus the routing facts the driver must not
     know about. }
   TLiveRotator = class(TObject)
   public
      Driver: TRotatorBase;
      Port: PortType;
      Bands: string;
      Name: string;
      { The heading this rotator was last told to reach.  Kept because the UDP
        path takes a HEADING while a driver produces BYTES -- see SendToRotator.
        Reconstructing it from the payload would work today and would break the
        first time a UDP rotator sent anything but bare digits. }
      LastHeading: integer;
      { THE UDP ENDPOINT, on the rotator rather than in a global.

        It was two globals -- PSTRotatorIPAddress and PSTRotatorUDPPort, fed by
        the PSTROTATOR IP ADDRESS / UDP PORT rows in tr4w.ini -- while the
        rotator LIBRARY had IPAddress and UDPPort on every definition, edited in
        Preferences and saved to tr4w.json. Two owners, and the one the operator
        could see did nothing: ConfigureRotators never carried those two fields
        across, so editing a PstRotator's address in Preferences saved happily
        and changed nothing about where the datagram went.

        Same shape as the band output port: a value with a visible editor and an
        invisible second owner. Holding it here makes the definition the single
        source, and means two PstRotator definitions on different hosts are
        expressible at all -- which a pair of globals could never be. }
      IPAddress: string;
      UDPPort: integer;
      { The driver's outlet. A METHOD on the live rotator rather than a closure
        capturing it: same effect, and it names the owner instead of implying it.
        Each driver is handed ITS OWN rotator's SendBytes, which is what stops
        one rotator's frame going out on another's wire. }
      procedure SendBytes(const aBytes: TBytes);
      destructor Destroy; override;
   end;

var
   GLive: TObjectList<TLiveRotator> = nil;

// Forward: SendBytes is a method on the type declared above, but the routine it
// delegates to needs PortFromName and the driver's UsesSerialPort, so it lives
// further down with the rest of the transport.
procedure SendToRotator(const aLive: TLiveRotator; const aBytes: TBytes); forward;

destructor TLiveRotator.Destroy;
begin
   FreeAndNil(Driver);
   inherited Destroy;
end;

procedure TLiveRotator.SendBytes(const aBytes: TBytes);
begin
   SendToRotator(Self, aBytes);
end;

function PortFromName(const aName: string): PortType;
var
   p: PortType;
begin
   // By NAME, through the same table the rest of the program uses.  An index
   // would re-point at a different port the day the list changes -- the trap the
   // radio store documents and the reason ControlPort is stored as text.
   Result := NoPort;
   for p := Low(PortType) to High(PortType) do
      begin
      if SameText(string(PortTypeSA[p]), aName) then
         begin
         Result := p;
         Exit;
         end;
      end;
end;

{ Does this rotator serve this band? }
function ServesBand(const aClaim, aBandName: string): boolean;
var
   claim: string;
begin
   claim := Trim(aClaim);

   // NO CLAIM MEANS EVERY BAND.  The common station has one rotator and one
   // antenna; making that operator enumerate bands to get the behaviour they
   // already had would be a feature charging rent.
   if claim = '' then
      begin
      Result := True;
      Exit;
      end;

   if Trim(aBandName) = '' then
      begin
      // The caller does not know the band.  A rotator that claimed specific
      // bands cannot be shown to serve this one, so it does not -- better a
      // rotator that does not move than the wrong one that does.
      Result := False;
      Exit;
      end;

   // Space-separated, matched whole: ' 20 ' inside ' 20 15 10 ' hits, and does
   // not also match the '20' inside '220'.
   Result := Pos(' ' + Trim(aBandName) + ' ', ' ' + claim + ' ') > 0;
end;

procedure SendToRotator(const aLive: TLiveRotator; const aBytes: TBytes);
var
   buf: array[0..63] of Byte;
   n: integer;
   i: integer;
begin
   if Length(aBytes) = 0 then
      begin
      Exit;
      end;

   if not aLive.Driver.UsesSerialPort then
      begin
      // PstRotator: its own UDP interface, which takes a heading rather than a
      // frame.  The legacy code reached this by returning early ABOVE the case;
      // here it is simply a different Send for a driver that answered
      // UsesSerialPort = False, and the routine that owns the socket is reused
      // untouched rather than reimplemented.
      SendPSTRotorCommand(aLive.LastHeading, aLive.IPAddress, aLive.UDPPort);
      Exit;
      end;

   if aLive.Port = NoPort then
      begin
      Exit;
      end;

   n := Length(aBytes);
   if n > Length(buf) then
      begin
      n := Length(buf);
      end;
   for i := 0 to n - 1 do
      begin
      buf[i] := aBytes[i];
      end;

   sWriteFile(CPUKeyer.SerialPortConfigured_Handle[aLive.Port], buf, n);

   logger.Trace('[uRotatorControl] %s (%s) on %s, %d bytes',
      [aLive.Name, aLive.Driver.DisplayName, string(PortTypeSA[aLive.Port]), n]);
end;

procedure ClearLive;
begin
   if GLive <> nil then
      begin
      GLive.Clear;
      end;
end;

procedure AddLive(const aName, aRotatorId, aPortName, aBands: string;
                  const aIPAddress: string = ''; const aUDPPort: integer = 0);
var
   live: TLiveRotator;
begin
   if GLive = nil then
      begin
      GLive := TObjectList<TLiveRotator>.Create(True);
      end;

   live := TLiveRotator.Create;
   live.Name  := aName;
   live.Port  := PortFromName(aPortName);
   live.Bands := aBands;

   // FALL BACK TO THE LEGACY GLOBALS RATHER THAN TO NOTHING. A definition made
   // before the library carried an endpoint has neither field set, and sending
   // to '' on port 0 would be a silent failure of exactly the kind this change
   // exists to remove. The globals still carry the tr4w.ini value, so an
   // unmigrated station keeps working and says so once in the log.
   live.IPAddress := aIPAddress;
   live.UDPPort   := aUDPPort;
   if live.IPAddress = '' then
      begin
      live.IPAddress := string(PSTRotatorIPAddress);
      end;
   if live.UDPPort = 0 then
      begin
      live.UDPPort := PSTRotatorUDPPort;
      end;
   if (aIPAddress = '') or (aUDPPort = 0) then
      begin
      logger.Info('[uRotatorControl] %s has no stored UDP endpoint; using the '
                  + 'legacy %s:%d from tr4w.ini',
                  [aName, live.IPAddress, live.UDPPort]);
      end;

   // Each driver gets ITS OWN rotator's SendBytes, so a driver's frame can only
   // reach that rotator's port.  A shared send would put one rotator's frame on
   // another's wire, which on a two-rotator station is exactly the failure that
   // is hardest to believe.
   //
   // Was an anonymous method capturing `live`; a method pointer says the same
   // thing while naming the owner, and compiles without closures.
   live.Driver := CreateRotator(aRotatorId, live.SendBytes);

   if live.Driver = nil then
      begin
      // An id this build does not have -- an old settings file, or a driver unit
      // dropped from the link.  Reported, not silently skipped: a rotator that
      // simply never moves is the hardest kind of problem to chase.
      logger.Error('[uRotatorControl] rotator "%s" names unknown type "%s" -- it will not turn',
                   [aName, aRotatorId]);
      live.Free;
      Exit;
      end;

   GLive.Add(live);
end;

procedure SeedFromLegacySettings;
var
   id: string;
begin
   // THE MIGRATION PATH.  An operator who has never opened the Rotators page
   // still has ROTATOR TYPE and ROTATOR PORT from their ini, and must keep
   // working exactly as before.  Seeding one rotator from those means there is
   // ONE code path from the first run -- which is what makes the legacy `case`
   // safe to delete rather than kept alive as a fallback that quietly drifts.
   if ActiveRotatorType = NoRotator then
      begin
      Exit;
      end;

   id := string(RotatorTypeSA[ActiveRotatorType]);
   // The legacy seed passes no endpoint on purpose: AddLive fills it from the
   // same globals this path already represents, in one place rather than two.
   AddLive('Rotator', id, string(PortTypeSA[ActiveRotatorPort]), '');
   logger.Info('[uRotatorControl] seeded one %s rotator from the legacy settings', [id]);
end;

procedure ConfigureRotators(const aStore: TRadioConfigStore);
var
   i: integer;
begin
   ClearLive;

   if aStore <> nil then
      begin
      for i := 0 to aStore.RotatorCount - 1 do
         begin
         AddLive(aStore.Rotator(i).Name,
                 aStore.Rotator(i).RotatorId,
                 aStore.Rotator(i).ControlPort,
                 aStore.Rotator(i).Bands,
                 aStore.Rotator(i).IPAddress,
                 aStore.Rotator(i).UDPPort);
         end;
      end;

   if LiveRotatorCount = 0 then
      begin
      SeedFromLegacySettings;
      end;

   logger.Info('[uRotatorControl] %d rotator(s) live', [LiveRotatorCount]);
end;

procedure TurnRotator(const aHeading: integer; const aBandName: string);
var
   i: integer;
   turned: boolean;
begin
   if GLive = nil then
      begin
      Exit;
      end;

   // EVERY rotator that claims this band, not just the first.  A station with
   // two antennas on one band has a reason for both, and picking one silently
   // would be this code deciding something the operator already decided.
   turned := False;
   for i := 0 to GLive.Count - 1 do
      begin
      if ServesBand(GLive[i].Bands, aBandName) then
         begin
         // Recorded BEFORE the turn: the send happens inside TurnTo, and the
         // UDP path reads it from here.
         GLive[i].LastHeading := aHeading;
         GLive[i].Driver.TurnTo(aHeading);
         turned := True;
         end;
      end;

   if not turned then
      begin
      logger.Debug('[uRotatorControl] no rotator serves band "%s" -- nothing turned',
                   [aBandName]);
      end;
end;

function LiveRotatorCount: integer;
begin
   if GLive = nil then
      begin
      Result := 0;
      end
   else
      begin
      Result := GLive.Count;
      end;
end;

initialization

finalization
   FreeAndNil(GLive);

end.

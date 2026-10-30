unit uWRLContact;
{$I tr4w.inc}

interface

(* Adapt a contact already interpreted by the contest/export pipeline. This
   unit knows ADIF and WRL field names, never contest types or park rules. *)
function WRLContactFromADIF(const aADIF, aStationCall: string): string;

implementation

uses
   SysUtils, Classes, fpjson, uADIF;

function WRLContactFromADIF(const aADIF, aStationCall: string): string;
var
   fields: TADIFFieldList;
   body, timestamp: TJSONObject;
   format: TFormatSettings;
   mode, station: string;

   function Value(const aName: string): string;
   var
      i: integer;
   begin
      Result := '';
      for i := 0 to High(fields) do
         begin
         if fields[i].Name = aName then
            begin
            Result := fields[i].Value;
            Exit;
            end;
         end;
   end;

   procedure TextField(const aADIFName, aJSONName: string; aRequired: boolean = False);
   var
      text: string;
   begin
      text := Value(aADIFName);
      if text <> '' then
         begin
         body.Add(UTF8Encode(aJSONName), UTF8Encode(text));
         end
      else if aRequired then
         begin
         raise EConvertError.Create(UTF8Encode('Contact is missing ' + aADIFName));
         end
      else
         begin
         body.Add(UTF8Encode(aJSONName), TJSONNull.Create);
         end;
   end;

   procedure NumberField(const aADIFName, aJSONName: string; aRequired: boolean = False);
   var
      number: Double;
      text: string;
   begin
      text := Value(aADIFName);
      if (text <> '') and TryStrToFloat(UTF8Encode(text), number, format) then
         begin
         body.Add(UTF8Encode(aJSONName), number);
         end
      else if aRequired then
         begin
         raise EConvertError.Create(UTF8Encode('Contact is missing a numeric ' + aADIFName));
         end
      else
         begin
         body.Add(UTF8Encode(aJSONName), TJSONNull.Create);
         end;
   end;

   procedure Activities(const aPrefix, aJSONName: string);
   var
      activities: TJSONArray;

      procedure AddReferences(const aTag, aType: string);
      var
         refs: TStringList;
         activity: TJSONObject;
         i: integer;
         reference: string;
      begin
         refs := TStringList.Create;
         try
            refs.StrictDelimiter := True;
            refs.Delimiter := ',';
            refs.DelimitedText := UTF8Encode(Value(aPrefix + aTag));
            for i := 0 to refs.Count - 1 do
               begin
               reference := Trim(UTF8Decode(refs[i]));
               if reference <> '' then
                  begin
                  activity := TJSONObject.Create;
                  activities.Add(activity);
                  activity.Add('type', UTF8Encode(aType));
                  activity.Add('ref', UTF8Encode(reference));
                  end;
               end;
         finally
            refs.Free;
         end;
      end;

   begin
      activities := TJSONArray.Create;
      body.Add(UTF8Encode(aJSONName), activities);
      AddReferences('POTA_REF', 'POTA');
      AddReferences('SOTA_REF', 'SOTA');
      AddReferences('WWFF_REF', 'WWFF');
      AddReferences('IOTA', 'IOTA');
   end;

begin
   if not ParseADIFFieldsList(aADIF, fields) then
      begin
      raise EConvertError.Create('Expected one complete ADIF contact');
      end;
   format := DefaultFormatSettings;
   format.DecimalSeparator := '.';
   body := TJSONObject.Create;
   try
      TextField('CALL', 'call', True);
      TextField('BAND', 'band', True);
      NumberField('FREQ', 'freq', True);
      timestamp := TJSONObject.Create;
      body.Add('timestamp', timestamp);
      if (Value('QSO_DATE') = '') or (Value('TIME_ON') = '') then
         begin
         raise EConvertError.Create('Contact is missing its UTC date/time');
         end;
      timestamp.Add('qsoDate', UTF8Encode(Value('QSO_DATE')));
      timestamp.Add('timeOn', UTF8Encode(Value('TIME_ON')));
      mode := Value('SUBMODE');
      if mode = '' then
         begin
         mode := Value('MODE');
         end;
      if mode = '' then
         begin
         raise EConvertError.Create('Contact is missing its mode');
         end;
      body.Add('mode', UTF8Encode(mode));
      station := Value('STATION_CALLSIGN');
      if station = '' then
         begin
         station := aStationCall;
         end;
      if station = '' then
         begin
         raise EConvertError.Create('Contact is missing its station callsign');
         end;
      body.Add('stationCallsign', UTF8Encode(station));
      if Value('OPERATOR') = '' then
         begin
         body.Add('operator', UTF8Encode(station));
         end
      else
         begin
         TextField('OPERATOR', 'operator');
         end;
      TextField('RST_SENT', 'rstSent');
      TextField('RST_RCVD', 'rstRcvd');
      TextField('TX_PWR', 'txPwr');
      TextField('NAME', 'name');
      TextField('GRIDSQUARE', 'gridsquare');
      TextField('MY_GRIDSQUARE', 'myGridsquare');
      TextField('QTH', 'qth');
      TextField('STATE', 'state');
      TextField('COMMENT', 'notes');
      Activities('MY_', 'myActivities');
      Activities('', 'theirActivities');
      Result := UTF8Decode(body.AsJSON);
   finally
      body.Free;
   end;
end;

end.

program rttiprobe;
(* Does the NATIVE FPC answer for settings actually work in THIS toolchain?

  A class with published properties, streamed to JSON and back by fpjsonrtti.
  No key table, no closures, no registry: the property NAME is the key and the
  property TYPE is the type.

  Compiled with TR4W's own mode -- Delphi mode plus UnicodeStrings -- because
  that combination is where this program's string surprises live. *)
{$MODE Delphi}
{$MODESWITCH UnicodeStrings}
{$APPTYPE CONSOLE}

uses
   SysUtils, Classes, fpjson, jsonparser, fpjsonrtti;

type
   TCwMode = (cwPaddle, cwKeyboard, cwBoth);

   (* NESTED, because settings group.  fpjsonrtti follows an object property
     when StreamChildren/ChildProperty is set. *)
   TUdpSettings = class(TPersistent)
   private
      FAddress: string;
      FPortScore: integer;
      FBroadcastAllQsos: boolean;
   published
      property Address: string read FAddress write FAddress;
      property PortScore: integer read FPortScore write FPortScore;
      property BroadcastAllQsos: boolean read FBroadcastAllQsos write FBroadcastAllQsos;
   end;

   TProbeSettings = class(TPersistent)
   private
      FMyCall: string;
      FCodeSpeed: integer;
      FSayHi: boolean;
      FCwMode: TCwMode;
      FQsoPointsDomesticCw: integer;
      FUdp: TUdpSettings;
   public
      constructor Create;
      destructor Destroy; override;
   published
      property MyCall: string read FMyCall write FMyCall;
      property CodeSpeed: integer read FCodeSpeed write FCodeSpeed;
      property SayHi: boolean read FSayHi write FSayHi;
      property CwMode: TCwMode read FCwMode write FCwMode;
      // THE ONE CFGCA COULD NOT HOLD: -1 means "the contest set no fixed value".
      property QsoPointsDomesticCw: integer read FQsoPointsDomesticCw write FQsoPointsDomesticCw;
      property Udp: TUdpSettings read FUdp;
   end;

constructor TProbeSettings.Create;
begin
   inherited Create;
   FUdp := TUdpSettings.Create;
end;

destructor TProbeSettings.Destroy;
begin
   FUdp.Free;
   inherited Destroy;
end;

var
   a, b: TProbeSettings;
   streamer: TJSONStreamer;
   destreamer: TJSONDeStreamer;
   text: string;
   ok: boolean;

begin
   a := TProbeSettings.Create;
   b := TProbeSettings.Create;
   streamer := TJSONStreamer.Create(nil);
   destreamer := TJSONDeStreamer.Create(nil);
   try
      a.MyCall              := 'NY4I';
      a.CodeSpeed           := 34;
      a.SayHi               := True;
      a.CwMode              := cwKeyboard;
      a.QsoPointsDomesticCw := -1;
      a.Udp.Address         := '192.168.1.255';
      a.Udp.PortScore       := 12060;
      a.Udp.BroadcastAllQsos := True;

      streamer.Options := streamer.Options + [jsoStreamChildren, jsoEnumeratedAsInteger];
      text := streamer.ObjectToJSONString(a);
      WriteLn('--- streamed ---');
      WriteLn(text);

      destreamer.JSONToObject(text, b);

      ok := (b.MyCall = 'NY4I') and (b.CodeSpeed = 34) and b.SayHi and
            (b.CwMode = cwKeyboard) and (b.QsoPointsDomesticCw = -1) and
            (b.Udp.Address = '192.168.1.255') and (b.Udp.PortScore = 12060) and
            b.Udp.BroadcastAllQsos;

      WriteLn;
      WriteLn('--- read back ---');
      WriteLn('  MyCall              = ', b.MyCall);
      WriteLn('  CodeSpeed           = ', b.CodeSpeed);
      WriteLn('  SayHi               = ', b.SayHi);
      WriteLn('  CwMode              = ', Ord(b.CwMode));
      WriteLn('  QsoPointsDomesticCw = ', b.QsoPointsDomesticCw);
      WriteLn('  Udp.Address         = ', b.Udp.Address);
      WriteLn('  Udp.PortScore       = ', b.Udp.PortScore);
      WriteLn('  Udp.BroadcastAllQsos= ', b.Udp.BroadcastAllQsos);
      WriteLn;
      if ok then WriteLn('ROUND TRIP OK') else WriteLn('ROUND TRIP FAILED');

      (* A KEY THE FILE DOES NOT CARRY MUST NOT DISTURB THE OBJECT -- that is
        what makes adding a setting safe against an older settings file. *)
      b.CodeSpeed := 99;
      destreamer.JSONToObject('{"MyCall":"W1AW"}', b);
      WriteLn('partial update: MyCall=', b.MyCall, ' CodeSpeed=', b.CodeSpeed,
              ' (CodeSpeed must still be 99)');
   finally
      destreamer.Free;
      streamer.Free;
      b.Free;
      a.Free;
   end;
end.

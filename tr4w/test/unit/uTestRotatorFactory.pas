unit uTestRotatorFactory;
{$I ..\..\src\tr4w.inc}

{
  The rotator factory, pinned against the code it replaces.

  WHY THESE ARE BYTE COMPARISONS.  This is a port, not a rewrite: LOGSTUFF's
  `case ActiveRotatorType of` produced specific bytes for each rotator, and the
  factory has to produce exactly those.  "Behaviour preserving" is a claim to be
  CHECKED -- the radio factory's RIT swap looked obviously equivalent and was
  not, and only comparing both directions caught it -- so every frame here is
  asserted against the legacy format spelled out again in the test.

  The legacy formats, from LOGSTUFF.RotorControl:

      OrionRotator     '#%03u'#$D
      DCU1Rotator      'AP1%03u;AM1;'
      YaesuRotator     'M%03u'#$D
      AlfaSpidRotator  'W%03u0'#01, heading+360, then 13 bytes with
                       [11]=$2F and [12]=$20
      PSTRotator       handled before the case -- UDP, azimuth as text

  A driver needs no port to test: the base takes a send closure, so the frames
  are captured in a buffer.  That is the point of the abstract transport, and it
  is why a bench is not needed to know the bytes are right.
}

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TRotatorFactoryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      function Frame(const aId: string; const aAzimuth: integer): TBytes;
      function FrameText(const aId: string; const aAzimuth: integer): string;

      procedure Test_AllFiveRotatorsAreRegistered;
      procedure Test_YaesuMatchesTheLegacyFormat;
      procedure Test_OrionMatchesTheLegacyFormat;
      procedure Test_DCU1SendsTargetAndStartTogether;
      procedure Test_AlfaSpidFrameIsThirteenBytes;
      procedure Test_AlfaSpidAddsThreeSixtyLikeTheLegacyCode;
      procedure Test_PSTRotatorIsTextAndNotSerial;
      procedure Test_AzimuthIsNormalisedOnce;
      procedure Test_DCU1IsTheOnlyOneWantingADifferentBaudRate;
      procedure Test_UnknownRotatorIsNilNotAnException;
      procedure Test_StopIsRefusedWhenNotSupported;
   end;

implementation

uses
   uRotatorBase,
   uRotatorRegistry,
   uRotatorYaesu,
   uRotatorOrion,
   uRotatorDCU1,
   uRotatorAlfaSpid,
   uRotatorPSTRotator;

type
   // The wire, captured. An OBJECT rather than an anonymous method over a
   // global: TRotatorSendProc is a method pointer now, and a probe object is
   // what the production side does too (TLiveRotator.SendBytes). One fewer
   // difference between how the test drives a driver and how the program does.
   TWireProbe = class
   public
      bytes: TBytes;
      procedure Send(const aBytes: TBytes);
   end;

procedure TWireProbe.Send(const aBytes: TBytes);
begin
   bytes := aBytes;
end;

function TRotatorFactoryTests.Frame(const aId: string; const aAzimuth: integer): TBytes;
var
   r: TRotatorBase;
   probe: TWireProbe;
begin
   probe := TWireProbe.Create;
   try
   r := CreateRotator(aId, probe.Send);
   try
      if r <> nil then
         begin
         r.TurnTo(aAzimuth);
         end;
   finally
      r.Free;
   end;
      Result := probe.bytes;
   finally
      probe.Free;
   end;
end;

function TRotatorFactoryTests.FrameText(const aId: string; const aAzimuth: integer): string;
var
   b: TBytes;
   i: integer;
begin
   Result := '';
   b := Frame(aId, aAzimuth);
   for i := 0 to High(b) do
      begin
      Result := Result + Char(b[i]);
      end;
end;

procedure TRotatorFactoryTests.Test_AllFiveRotatorsAreRegistered;
begin
   BeginTest('all five rotators self-register');
   // THE ONE HAZARD OF SELF-REGISTRATION: a unit dropped from the project link
   // registers nothing and fails SILENTLY -- the rotator is simply not offered,
   // and nobody notices until an operator who owns one goes looking.  Asserting
   // the count is what turns that into a failing build, and it is the same
   // guard uRadioRegistry carries.
   CheckEquals(5, RegisteredCount, 'five rotator drivers');
   CheckTrue(IsRegistered('YAESU'),      'Yaesu');
   CheckTrue(IsRegistered('ORION'),      'Orion');
   CheckTrue(IsRegistered('DCU1'),       'DCU-1');
   CheckTrue(IsRegistered('ALFA SPID'),  'Alfa SPID');
   CheckTrue(IsRegistered('PSTROTATOR'), 'PstRotator');

   // The ids are the LEGACY spellings from RotatorTypeSA, so an existing
   // ROTATOR TYPE line in an operator's ini still names something real while
   // the two systems overlap.
   CheckEquals('Alfa SPID', RotatorDisplayName('ALFA SPID'), 'display name');
end;

procedure TRotatorFactoryTests.Test_YaesuMatchesTheLegacyFormat;
begin
   BeginTest('Yaesu: M + three digits + CR, exactly as the legacy format');
   CheckEquals('M090' + #$0D, FrameText('YAESU', 90),  'M%03u CR at 90');
   CheckEquals('M000' + #$0D, FrameText('YAESU', 0),   'zero padded at 0');
   CheckEquals('M359' + #$0D, FrameText('YAESU', 359), 'three digits at 359');
end;

procedure TRotatorFactoryTests.Test_OrionMatchesTheLegacyFormat;
begin
   BeginTest('Orion: # + three digits + CR, exactly as the legacy format');
   CheckEquals('#090' + #$0D, FrameText('ORION', 90),  '#%03u CR at 90');
   CheckEquals('#005' + #$0D, FrameText('ORION', 5),   'zero padded at 5');
end;

procedure TRotatorFactoryTests.Test_DCU1SendsTargetAndStartTogether;
var
   s: string;
begin
   BeginTest('DCU-1: target AND start in ONE frame');
   s := FrameText('DCU1', 90);
   CheckEquals('AP1090;AM1;', s, 'AP1%03u;AM1; at 90');

   // The half that matters operationally: AP1 sets a target, AM1 starts the
   // move.  Sending AP1 alone leaves the rotator holding a target it never
   // turns to, which on the bench looks exactly like a dead rotator.
   CheckTrue(Pos('AM1;', s) > 0, 'the start command is present');
end;

procedure TRotatorFactoryTests.Test_AlfaSpidFrameIsThirteenBytes;
var
   b: TBytes;
begin
   BeginTest('Alfa SPID: thirteen bytes, with the trailing 2F 20');
   b := Frame('ALFA SPID', 90);
   CheckEquals(13, Length(b), 'the legacy code forced the length to 13');

   CheckEquals(Ord('W'), b[0], 'starts with W');
   CheckEquals($01, b[5],  'azimuth resolution byte');
   CheckEquals($2F, b[11], 'byte 11 is 2F, as the legacy code patched it');
   CheckEquals($20, b[12], 'byte 12 is 20, as the legacy code patched it');

   // Elevation stays zero: the legacy path never wrote those bytes, and TR4W
   // drives azimuth only.  Filling them in would be a behaviour change dressed
   // as a tidy-up.
   CheckEquals(0, b[6],  'elevation digit 1 left zero');
   CheckEquals(0, b[9],  'elevation digit 4 left zero');
   CheckEquals(0, b[10], 'elevation resolution left zero');
end;

procedure TRotatorFactoryTests.Test_AlfaSpidAddsThreeSixtyLikeTheLegacyCode;
var
   b: TBytes;
begin
   BeginTest('Alfa SPID: azimuth carried as heading + 360');
   // inc(Heading, 360) in the legacy code.  A SPID convention -- the wire value
   // is never negative -- and it belongs to this driver rather than to TR4W,
   // which is why the base normalises to 0..359 and knows nothing about it.
   b := Frame('ALFA SPID', 90);
   CheckEquals(Ord('4'), b[1], '90 + 360 = 450, first digit');
   CheckEquals(Ord('5'), b[2], 'second digit');
   CheckEquals(Ord('0'), b[3], 'third digit');
   CheckEquals(Ord('0'), b[4], 'the literal 0 the legacy format appended');

   b := Frame('ALFA SPID', 0);
   CheckEquals(Ord('3'), b[1], '0 + 360 = 360');
   CheckEquals(Ord('6'), b[2], '');
   CheckEquals(Ord('0'), b[3], '');
end;

procedure TRotatorFactoryTests.Test_PSTRotatorIsTextAndNotSerial;
var
   r: TRotatorBase;
begin
   BeginTest('PstRotator: plain text, and it does NOT use a serial port');
   CheckEquals('090', FrameText('PSTROTATOR', 90), 'azimuth as text');

   // The legacy code returned early for this type because it has no port.  That
   // early return is now a property of the driver, so the port-opening path can
   // ask instead of knowing.
   r := CreateRotator('PSTROTATOR', nil);
   try
      CheckFalse(r.UsesSerialPort, 'PstRotator is UDP');
   finally
      r.Free;
   end;

   r := CreateRotator('YAESU', nil);
   try
      CheckTrue(r.UsesSerialPort, 'and the others are serial');
   finally
      r.Free;
   end;
end;

procedure TRotatorFactoryTests.Test_AzimuthIsNormalisedOnce;
begin
   BeginTest('an out-of-range azimuth is normalised by the BASE, once');
   // A caller computing a bearing can easily produce 360 or a negative number.
   // Normalising in the base means no driver has to remember, and a frame the
   // rotator would reject cannot be built at all.
   CheckEquals('M000' + #$0D, FrameText('YAESU', 360),  '360 is 0');
   CheckEquals('M350' + #$0D, FrameText('YAESU', -10),  '-10 is 350');
   CheckEquals('M090' + #$0D, FrameText('YAESU', 450),  '450 is 90');

   // And the SPID +360 is applied to the NORMALISED value, not the raw one --
   // otherwise 450 would go out as 810.
   CheckEquals(Ord('4'), Frame('ALFA SPID', 450)[1], '450 normalises to 90, then +360');
end;

procedure TRotatorFactoryTests.Test_DCU1IsTheOnlyOneWantingADifferentBaudRate;
var
   r: TRotatorBase;
begin
   BeginTest('the DCU-1 carries its own 4800 baud; the rest take the default');
   // LogCfg.pas:293 was `if ActiveRotatorType = DCU1Rotator then BaudRate := 4800`
   // -- the only per-type branch in the port-opening path.  It is now a fact the
   // driver states about itself.
   r := CreateRotator('DCU1', nil);
   try
      CheckEquals(4800, r.PreferredBaudRate, 'DCU-1 wants 4800');
   finally
      r.Free;
   end;

   r := CreateRotator('YAESU', nil);
   try
      CheckEquals(9600, r.PreferredBaudRate, 'the others take the default');
   finally
      r.Free;
   end;
end;

procedure TRotatorFactoryTests.Test_UnknownRotatorIsNilNotAnException;
var
   r: TRotatorBase;
begin
   BeginTest('an unknown rotator id returns nil rather than raising');
   // A legitimate answer: an ini naming a rotator this build does not have.
   // Raising would take out a startup path over a configuration problem the
   // caller can report perfectly well.
   r := CreateRotator('YAESU G-5500 MK VII', nil);
   CheckTrue(r = nil, 'unknown id is nil');
end;

procedure TRotatorFactoryTests.Test_StopIsRefusedWhenNotSupported;
var
   r: TRotatorBase;
   probe: TWireProbe;
begin
   BeginTest('Stop sends nothing when the driver does not declare rcStop');
   // None of the five has a stop command ported yet.  The capability and the
   // StopFrame override go together; asserting that Stop is silent without the
   // capability is what stops a future driver declaring one and forgetting the
   // other -- an empty frame would otherwise be sent to a live rotator.
   probe := TWireProbe.Create;
   probe.bytes := nil;
   r := CreateRotator('YAESU', probe.Send);
   try
      CheckFalse(r.Supports(rcStop), 'no stop capability declared');
      r.Stop;
      CheckTrue(probe.bytes = nil, 'and nothing was sent');

      CheckTrue(r.Supports(rcTurn), 'every rotator turns, without declaring it');
   finally
      r.Free;
      probe.Free;
   end;
end;

procedure TRotatorFactoryTests.RunAllTests;
begin
   Test_AllFiveRotatorsAreRegistered;
   Test_YaesuMatchesTheLegacyFormat;
   Test_OrionMatchesTheLegacyFormat;
   Test_DCU1SendsTargetAndStartTogether;
   Test_AlfaSpidFrameIsThirteenBytes;
   Test_AlfaSpidAddsThreeSixtyLikeTheLegacyCode;
   Test_PSTRotatorIsTextAndNotSerial;
   Test_AzimuthIsNormalisedOnce;
   Test_DCU1IsTheOnlyOneWantingADifferentBaudRate;
   Test_UnknownRotatorIsNilNotAnException;
   Test_StopIsRefusedWhenNotSupported;
end;

end.

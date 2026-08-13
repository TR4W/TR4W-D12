unit uTestAutoInfo;
{$I ..\..\src\tr4w.inc}

{
  Auto-info level resolution across the Elecraft family.

  WHY THIS EXISTS.  "A negative level means YOU DECIDE, and this family says 2"
  is a default that lives in code rather than in a table, deliberately -- so a
  new thin subclass inherits it with no list to remember to update.  The cost of
  that choice is that a regression is INVISIBLE: if the default silently became
  0, every Elecraft would quietly go back to full polling and a slow unkey, the
  program would build clean, every other test would pass, and the only symptom
  would be a bench measurement nobody re-runs.  That is the "silently-defaulted
  field reads as a legal zero" trap, so the pin test is written WITH the change.

  THE K4 IS THE INTERESTING CASE and the reason this file is not three lines.
  It is the only radio where this setting means different things on different
  transports:

      SERIAL   the operator's level, defaulting to 2, with the poll as a
               backstop -- so 0 is a legitimate answer meaning "off"
      NETWORK  always AI5, set per connection, NOT the operator's to choose:
               a K4 network session always starts at AI0, and the network path
               has no poll to fall back on (PollRadioState sends only PING;),
               so an operator who set 0 would get a radio reporting NOTHING

  The K4 is also deliberately NOT a TElecraftSerial, so it reaches the same
  default by its own route.  Two independent code paths that must agree is
  precisely the shape that drifts -- the K3 and K4 already parsed the same IF
  response twice and drifted, fixing the same RIT/XIT bug twice -- so their
  agreement is asserted rather than assumed.

  WHAT THIS CANNOT TEST.  Whether the radio actually honours AI2, and whether
  the unkey gets faster.  Both need hardware.  What is pinned here is the
  DECISION, which is the part that can regress silently.
}

interface

uses
   SysUtils, uTR4WTestFramework, VC, uFactoryRadioBase;

type
   TAutoInfoTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      // Returns the resolved level for a registry model, or a sentinel.
      function  ResolveElecraftSerial(model: InterfacedRadioType; request: integer): integer;
      function  ResolveK4(request: integer; asSerial: boolean): integer;

      procedure Test_NegativeMeansTheFamilyDefaultOfTwo;
      procedure Test_ZeroIsRespectedAsOperatorOff;
      procedure Test_AnExplicitLevelIsPassedThrough;
      procedure Test_K4AgreesWithItsCousinsOnTheDefault;
      procedure Test_K4StoresTheLevelOnBothTransports;
   end;

implementation

uses
   uRadioRegistry, uRadioElecraftSerial, uRadioElecraftK4;

const
   // The one number this whole file is about.
   EXPECTED_FAMILY_DEFAULT = 2;

   // "You decide" -- matches AUTOINFO_RADIO_DEFAULT in uRadioConfigStore.
   ASK_THE_DRIVER = -1;

function TAutoInfoTests.ResolveElecraftSerial(model: InterfacedRadioType;
                                              request: integer): integer;
var
   r: TFactoryRadioBase;
begin
   Result := MaxInt;   // sentinel: could not construct
   r := uRadioRegistry.CreateInstance(model);
   if r = nil then
      begin
      Exit;
      end;
   try
      if r is TElecraftSerial then
         begin
         TElecraftSerial(r).ApplyAutoInfoLevel(request);
         Result := TElecraftSerial(r).AutoInfoLevel;
         end;
   finally
      r.Free;
   end;
end;

function TAutoInfoTests.ResolveK4(request: integer; asSerial: boolean): integer;
var
   r: TFactoryRadioBase;
begin
   Result := MaxInt;
   r := uRadioRegistry.CreateInstance(K4);
   if r = nil then
      begin
      Exit;
      end;
   try
      if r is TK4Radio then
         begin
         // The transport is what the driver branches on.  A fresh instance has
         // no port, which IS the network case -- so only the serial case needs
         // arranging.
         if asSerial then
            begin
            // Any real port will do -- the driver tests <> NoPort, not which
            // one.  Serial1 rather than a number: PortType is an enum whose
            // zero element IS NoPort, so an integer would both fail to compile
            // and, if forced, mean the opposite of what is wanted here.
            TK4Radio(r).serialPort := Serial1;
            end;
         TK4Radio(r).ApplyAutoInfoLevel(request);
         Result := TK4Radio(r).AutoInfoLevel;
         end;
   finally
      r.Free;
   end;
end;

procedure TAutoInfoTests.Test_NegativeMeansTheFamilyDefaultOfTwo;
begin
   BeginTest('a negative level resolves to the family default of 2');

   CheckEquals(EXPECTED_FAMILY_DEFAULT, ResolveElecraftSerial(K2, ASK_THE_DRIVER),
               'K2 defaults to AI2');
   CheckEquals(EXPECTED_FAMILY_DEFAULT, ResolveElecraftSerial(K3, ASK_THE_DRIVER),
               'K3 defaults to AI2');
   CheckEquals(EXPECTED_FAMILY_DEFAULT, ResolveElecraftSerial(KX3, ASK_THE_DRIVER),
               'KX3 defaults to AI2');

   // A KX2 shares the KX3 command set (NY4I) and is not yet a registered
   // model.  When it is added as a thin subclass it must land here for free --
   // that is the entire argument for deciding the default in code rather than
   // in a per-model table, so this test will be extended, not rewritten.

   CheckEquals(EXPECTED_FAMILY_DEFAULT, ResolveK4(ASK_THE_DRIVER, True),
               'serial K4 defaults to AI2');
end;

procedure TAutoInfoTests.Test_ZeroIsRespectedAsOperatorOff;
begin
   BeginTest('zero is the operator saying OFF and is not re-defaulted');

   // The distinction that makes the negative sentinel necessary at all: 0 and
   // "not chosen" are different answers, and 0 must survive.  If this ever
   // fails, the operator has lost the ability to turn auto-info off -- which
   // is the documented first thing to try when a rig misbehaves with it.
   CheckEquals(0, ResolveElecraftSerial(K3, 0),  'K3 honours an explicit 0');
   CheckEquals(0, ResolveElecraftSerial(K2, 0),  'K2 honours an explicit 0');
   CheckEquals(0, ResolveElecraftSerial(KX3, 0), 'KX3 honours an explicit 0');
   CheckEquals(0, ResolveK4(0, True),            'serial K4 honours an explicit 0');
end;

procedure TAutoInfoTests.Test_AnExplicitLevelIsPassedThrough;
begin
   BeginTest('an explicit non-default level is passed through unchanged');

   CheckEquals(1, ResolveElecraftSerial(K3, 1), 'K3 accepts AI1');
   CheckEquals(3, ResolveElecraftSerial(K3, 3), 'K3 accepts AI3');
   CheckEquals(3, ResolveK4(3, True),           'serial K4 accepts AI3');
end;

procedure TAutoInfoTests.Test_K4AgreesWithItsCousinsOnTheDefault;
var
   k3Default, k4Default: integer;
begin
   BeginTest('the K4 reaches the same default as the K2/K3/KX3 by its own route');

   // The K4 is deliberately not a TElecraftSerial, so this agreement is a
   // COINCIDENCE MAINTAINED BY HAND, not something the type system enforces.
   // These two classes have drifted before on shared behaviour (the same
   // RIT/XIT bug was fixed twice, once in each IF parser), so the agreement is
   // asserted directly rather than left to two separate tests that would both
   // pass while disagreeing.
   k3Default := ResolveElecraftSerial(K3, ASK_THE_DRIVER);
   k4Default := ResolveK4(ASK_THE_DRIVER, True);

   CheckEquals(k3Default, k4Default,
               'serial K4 and K3 must agree on the "you decide" default');
end;

procedure TAutoInfoTests.Test_K4StoresTheLevelOnBothTransports;
begin
   BeginTest('the K4 resolves the level on both transports; only serial acts on it');

   // The network K4 STORES a resolved level -- the branch that ignores it is
   // in Connect/Initialize/PollRadioState, which send AI5 regardless and
   // cannot be exercised without a socket.  What is pinned here is that asking
   // on the network path is harmless and does not, say, leave the field at an
   // uninitialised zero that a later serial reconnect would then use.
   CheckEquals(EXPECTED_FAMILY_DEFAULT, ResolveK4(ASK_THE_DRIVER, False),
               'a network K4 still resolves the default rather than leaving 0');

   // NOT TESTED HERE, AND DELIBERATELY SO: that a network K4 sends AI5 and
   // ignores this value.  That needs a connection.  The guard against a
   // muted network K4 is therefore TWO-LAYERED -- the driver ignores the
   // setting (TK4Radio.Connect / Initialize) AND the radio editor hides the
   // control on the network tab (uRadioEditForm.UpdateEnabledState) -- because
   // neither layer is provable here.
end;

procedure TAutoInfoTests.RunAllTests;
begin
   Test_NegativeMeansTheFamilyDefaultOfTwo;
   Test_ZeroIsRespectedAsOperatorOff;
   Test_AnExplicitLevelIsPassedThrough;
   Test_K4AgreesWithItsCousinsOnTheDefault;
   Test_K4StoresTheLevelOnBothTransports;
end;

end.

unit uTestRadioKeepAlive;
{$I ..\..\src\tr4w.inc}

(*
  Issue 6: a network radio's keep-alive and TR4W-side silence detection.

  A Flex (SmartSDR API) that loses power or its cable sends no TCP FIN, so the
  socket stays "open" and TR4W showed a dead radio as connected.  The radio
  now declares a keep-alive interval and a silence limit in its constructor
  (TRadioCapabilities.KeepAliveIntervalMs / .LinkSilenceLimitMs), the Flex
  sends `ping` through the virtual SendKeepAlive, and the base's
  MaintainKeepAlive drops a link that has been silent past the limit so the
  polling thread's reconnect-with-backoff takes over.

  These tests pin:
    - the pure arithmetic, including the cross-thread race where the reading
      thread stamps "heard" after the polling thread read the clock;
    - over the WHOLE REGISTRY, every link: the Flex API is the one radio that
      declares either number -- a radio that gains one with no driver behind
      it fails here by name;
    - the Flex pings once a second, and not before its handshake;
    - silence past the limit drops the link, and no ping goes with it;
    - the base guards on the trait, never on the model: a Flex with the two
      numbers cleared neither pings nor drops.

  NO TRANSPORT: the probe overrides SendToRadio and drops the C<seq>| prefix.
  Whether a real radio answers `ping` with keepalive disabled is
  docs/BENCH_QUEUE.md's question, not this file's.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioFlexAPI, uRadioRegistry;

type
   TRadioKeepAliveTests = class(TTestCase)
   protected
      procedure Test_KeepAliveDue_Arithmetic;
      procedure Test_LinkSilence_Arithmetic;
      procedure Test_OnlyTheFlexAPIDeclaresAKeepAlive;
      procedure Test_FlexPingsEverySecondAfterTheHandshake;
      procedure Test_FlexSilencePastTheLimitDropsTheLink;
      procedure Test_RadioWithoutTheTrait_NeitherPingsNorDrops;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TFlexKeepAliveProbe = class(TFlexAPI)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
      function Tick(nowTick: QWord): boolean;
   end;

   (* The same driver with the two numbers cleared: proves the base acts on
     the declared trait and not on which class it is. *)
   TFlexWithoutKeepAlive = class(TFlexKeepAliveProbe)
   public
      constructor Create;
   end;

procedure TFlexKeepAliveProbe.SendToRadio(s: string);
begin
   sent := sent + Copy(s, Pos('|', s) + 1, Length(s)) + ';';
end;

function TFlexKeepAliveProbe.Tick(nowTick: QWord): boolean;
begin
   Result := MaintainKeepAliveAt(nowTick);
end;

constructor TFlexWithoutKeepAlive.Create;
begin
   inherited Create;
   FCapabilities.KeepAliveIntervalMs := 0;
   FCapabilities.LinkSilenceLimitMs := 0;
end;

procedure TRadioKeepAliveTests.Test_KeepAliveDue_Arithmetic;
begin
   BeginTest('KeepAliveDue: 0 is never, never-sent is now, a whole interval is due');
   CheckFalse(KeepAliveDue(50000, 0, 0), 'an interval of 0 is never due');
   CheckTrue(KeepAliveDue(50000, 0, 1000), 'a keep-alive never sent is due at once');
   CheckFalse(KeepAliveDue(50999, 50000, 1000), 'one millisecond short is not due');
   CheckTrue(KeepAliveDue(51000, 50000, 1000), 'exactly one interval is due');
   CheckTrue(KeepAliveDue(90000, 50000, 1000), 'long overdue is due');
   CheckFalse(KeepAliveDue(49000, 50000, 1000),
              'sent AFTER now is not due -- the subtraction must not wrap');
end;

procedure TRadioKeepAliveTests.Test_LinkSilence_Arithmetic;
begin
   BeginTest('LinkSilenceExceeded: 0 never trips, MORE than the limit trips, a later stamp is not silence');
   CheckFalse(LinkSilenceExceeded(900000, 0, 0), 'a limit of 0 never trips');
   CheckFalse(LinkSilenceExceeded(60000, 50000, 10000), 'exactly the limit is not yet silence');
   CheckTrue(LinkSilenceExceeded(60001, 50000, 10000), 'one millisecond past the limit is silence');
   CheckFalse(LinkSilenceExceeded(55000, 50000, 10000), 'inside the limit is not silence');
   CheckFalse(LinkSilenceExceeded(50000, 50001, 10000),
              'heard AFTER the clock was read (the reading thread won the race) is not silence -- ' +
              'QWord subtraction would otherwise wrap and drop a radio that has just spoken');
end;

(* THE REGISTRY WALK, every id on every link it claims -- FLEX has two
  constructors, so CreateInstanceId alone would build only one of them. *)
procedure TRadioKeepAliveTests.Test_OnlyTheFlexAPIDeclaresAKeepAlive;
var
   ids: TArray<string>;
   id: string;
   link: TRadioLink;
   r: TFactoryRadioBase;
   declared: string;
   checked: integer;
begin
   BeginTest('Registry: the Flex API (network) is the one radio that declares a keep-alive or silence limit');
   declared := '';
   checked := 0;
   ids := uRadioRegistry.RegisteredIds;
   for id in ids do
      begin
      for link := Low(TRadioLink) to High(TRadioLink) do
         begin
         if ((link = rlSerial) and not uRadioRegistry.SupportsSerialId(id)) or
            ((link = rlNetwork) and not uRadioRegistry.SupportsNetworkId(id)) then
            begin
            Continue;
            end;
         r := uRadioRegistry.CreateInstanceForLinkId(id, link);
         if r = nil then
            begin
            Continue;
            end;
         try
            Inc(checked);
            if (r.Capabilities.KeepAliveIntervalMs <> 0) or
               (r.Capabilities.LinkSilenceLimitMs <> 0) then
               begin
               if link = rlSerial then
                  begin
                  declared := declared + uRadioRegistry.DisplayNameId(id) + '/serial ';
                  end
               else
                  begin
                  declared := declared + uRadioRegistry.DisplayNameId(id) + '/network ';
                  end;
               end;
         finally
            r.Free;
         end;
         end;
      end;

   CheckTrue(checked > 0, 'the registry produced no radios to check');
   CheckEquals('Flex 6000+/network ', declared,
               'exactly one radio declares a keep-alive, and it is the SmartSDR API driver -- ' +
               'the only one with a SendKeepAlive behind it');
end;

procedure TRadioKeepAliveTests.Test_FlexPingsEverySecondAfterTheHandshake;
var
   r: TFlexKeepAliveProbe;
   t0: QWord;
begin
   BeginTest('Flex: ping once a second, and nothing before the H line');
   r := TFlexKeepAliveProbe.Create;
   try
      CheckEquals(FLEX_PING_INTERVAL_MS, integer(r.Capabilities.KeepAliveIntervalMs),
                  'the Flex declares its ping interval');
      CheckEquals(FLEX_LINK_SILENCE_LIMIT_MS, integer(r.Capabilities.LinkSilenceLimitMs),
                  'the Flex declares its silence limit');

      t0 := GetTickCount64;
      CheckFalse(r.Tick(t0), 'no drop before the handshake');
      CheckEquals('', r.sent, 'no ping before the radio has sent its H line');

      r.ProcessMsg('H2A3B4C5D');
      r.sent := '';

      CheckFalse(r.Tick(t0 + FLEX_PING_INTERVAL_MS), 'a talking radio is not dropped');
      CheckEquals(FLEX_PING_COMMAND + ';', r.sent, 'one ping once the interval has passed');

      r.sent := '';
      r.Tick(t0 + FLEX_PING_INTERVAL_MS + 500);
      CheckEquals('', r.sent, 'half an interval later, nothing');

      r.Tick(t0 + 2 * FLEX_PING_INTERVAL_MS);
      CheckEquals(FLEX_PING_COMMAND + ';', r.sent, 'the next ping a whole interval after the last');
   finally
      r.Free;
   end;
end;

procedure TRadioKeepAliveTests.Test_FlexSilencePastTheLimitDropsTheLink;
var
   r: TFlexKeepAliveProbe;
   t0: QWord;
begin
   BeginTest('Flex: silence past the limit drops the link; a later stamp is not silence');
   r := TFlexKeepAliveProbe.Create;
   try
      r.ProcessMsg('H2A3B4C5D');     // the radio spoke: the silence clock is now
      t0 := GetTickCount64;
      r.sent := '';

      CheckFalse(r.Tick(t0 - 1000),
                 'a clock read BEFORE the last frame is not silence (the cross-thread race)');
      CheckFalse(r.Tick(t0 + FLEX_LINK_SILENCE_LIMIT_MS div 2), 'half the limit: still up');

      r.sent := '';
      CheckTrue(r.Tick(t0 + FLEX_LINK_SILENCE_LIMIT_MS + 1),
                'nothing heard for more than the limit: the radio drops its own link');
      CheckEquals('', r.sent, 'a link declared dead is not pinged on the way down');
   finally
      r.Free;
   end;
end;

procedure TRadioKeepAliveTests.Test_RadioWithoutTheTrait_NeitherPingsNorDrops;
var
   r: TFlexWithoutKeepAlive;
   t0: QWord;
begin
   BeginTest('A radio that declares no keep-alive neither pings nor drops, whatever its class');
   r := TFlexWithoutKeepAlive.Create;
   try
      r.ProcessMsg('H2A3B4C5D');
      t0 := GetTickCount64;
      r.sent := '';
      CheckFalse(r.Tick(t0 + 3600000), 'an hour of silence drops nothing without a declared limit');
      CheckEquals('', r.sent, 'and nothing is sent without a declared interval');
   finally
      r.Free;
   end;
end;

procedure TRadioKeepAliveTests.RunAllTests;
begin
   Test_KeepAliveDue_Arithmetic;
   Test_LinkSilence_Arithmetic;
   Test_OnlyTheFlexAPIDeclaresAKeepAlive;
   Test_FlexPingsEverySecondAfterTheHandshake;
   Test_FlexSilencePastTheLimitDropsTheLink;
   Test_RadioWithoutTheTrait_NeitherPingsNorDrops;
end;

end.

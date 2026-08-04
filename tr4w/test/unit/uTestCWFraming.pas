unit uTestCWFraming;

{
  Two things are pinned here.

  1. THE MECHANISM (uCWFraming): given a frame rule, cut a message up; given a
     dialect, spell a prosign.  Pure string manipulation, no radio involved.

  2. THE DATA, which as of 2026-08-03 lives on the RADIO OBJECT
     (TRadioCapabilities.CWFrame / .CWProsignDialect) rather than in a table
     keyed on InterfacedRadioType.  Test_DeclaredRulesArePinned constructs every
     registered radio and checks what it declares against the table the model
     lookup used to return.

  Why (2) matters more than it looks.  An undeclared frame rule is a zeroed
  record, and a zeroed record means "no limit, no padding" -- a legal, silent
  answer.  A family base that forgets to state its rule therefore compiles
  clean and simply stops chunking, which on a Kenwood means a 24-byte KY gets
  a 40-byte payload.  The pin table is exhaustive and the test FAILS on any
  radio that declares rcCWByCAT without appearing in it, so a new keying radio
  cannot be added without stating what its CW command accepts.

  These are BENCH-DERIVED FACTS about real radios -- particularly the K3/K4
  padding rule, which exists because of a specific 2026-06-18 finding (a short
  KY is swallowed by the keyer-abort window that precedes it).
}

interface

uses
   SysUtils, uTR4WTestFramework, uCWFraming, uFactoryRadioBase, uRadioRegistry, VC;

type
   TCWFramingTests = class(TTestCase)
   protected
      procedure Test_DeclaredRulesArePinned;
      procedure Test_EveryKeyingRadioIsPinned;
      procedure Test_ChunkingAndPadding;
      procedure Test_ElementCountUsesUnpaddedText;
      procedure Test_EdgeCases;
      procedure Test_ProsignsDifferByDialect;
      procedure Test_IcomIsAThirdDialect;
      procedure Test_NoneDialectPassesEverythingThrough;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   // One row per radio that can key CW by CAT.  EXHAUSTIVE -- see the unit
   // header; Test_EveryKeyingRadioIsPinned enforces that.
   TCWPin = record
      model:      InterfacedRadioType;
      link:       TRadioLink;   // which ctor: only FLEX has two
      name:       string;
      maxLen:     integer;
      pad:        boolean;
      busyPct:    integer;      // busyFactor x 100, so it can be compared as an integer
      // What this radio keys for SK and for SN.  SK tells the three grammars
      // apart ('*' Elecraft, '>' Kenwood, '^SK' Icom); SN is the one that
      // catches a DECLARED-but-empty spelling being confused with an
      // undeclared grammar, since Elecraft alone consumes it and keys nothing.
      skText:     string;
      snText:     string;
   end;

const
   CW_PINS: array[0..28] of TCWPin = (
      // Elecraft: 22 and padded, to survive the keyer-abort window.  The K2 is
      // the family's one deviation -- same length, no padding.
      (model: K2;     link: rlSerial;  name: 'K2';     maxLen: 22; pad: False; busyPct: 100; skText: '*';    snText: ''),
      (model: K3;     link: rlSerial;  name: 'K3';     maxLen: 22; pad: True;  busyPct: 100; skText: '*';    snText: ''),
      (model: KX3;    link: rlSerial;  name: 'KX3';    maxLen: 22; pad: True;  busyPct: 100; skText: '*';    snText: ''),
      (model: K4;     link: rlNetwork; name: 'K4';     maxLen: 22; pad: True;  busyPct: 100; skText: '*';    snText: ''),
      // Kenwood: KY takes 24 and rejects a short P2 under P1=space, so it fills.
      (model: TS480;  link: rlSerial;  name: 'TS-480'; maxLen: 24; pad: True;  busyPct: 100; skText: '>';    snText: '%'),
      (model: TS570;  link: rlSerial;  name: 'TS-570'; maxLen: 24; pad: True;  busyPct: 100; skText: '>';    snText: '%'),
      (model: TS590;  link: rlSerial;  name: 'TS-590'; maxLen: 24; pad: True;  busyPct: 100; skText: '>';    snText: '%'),
      (model: TS2000; link: rlSerial;  name: 'TS-2000';maxLen: 24; pad: True;  busyPct: 100; skText: '>';    snText: '%'),
      // The TS-850 was NOT in the old model table even though it declares
      // rcCWByCAT, so it fell to "no limit, no padding" (and in D7, to an
      // uninitialised maxLen).  As a TKenwoodSerial it now gets the family rule.
      (model: TS850;  link: rlSerial;  name: 'TS-850'; maxLen: 24; pad: True;  busyPct: 100; skText: '>';    snText: '%'),
      (model: TS990;  link: rlNetwork; name: 'TS-990'; maxLen: 24; pad: True;  busyPct: 100; skText: '>';    snText: '%'),
      // The TS-890 takes a variable-length P2, so no fill.
      (model: TS890;  link: rlNetwork; name: 'TS-890'; maxLen: 24; pad: False; busyPct: 100; skText: '>';    snText: '%'),
      // Flex: two protocols, two classes, two rules.  This pair is what the old
      // `network: boolean` parameter existed to express.
      (model: FLEX;   link: rlSerial;  name: 'Flex CAT'; maxLen: 24; pad: True;  busyPct: 100; skText: '>';    snText: '%'),
      (model: FLEX;   link: rlNetwork; name: 'Flex API'; maxLen: 0;  pad: False; busyPct: 100; skText: '>';    snText: '%'),
      // Icom: 28 per send, and a 1.25 safety factor on the busy window because
      // the CI-V send queue is rate limited.  Every keying Icom is listed
      // individually rather than covered by a range: the rule reaches them by
      // INHERITANCE, and this test's whole job is to prove that it arrives.  It
      // did not, on the first run -- the value was set in DefineCapabilities,
      // which every subclass replaces, and all fourteen came out with maxLen 0.
      (model: IC705;    link: rlSerial; name: 'IC-705';    maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC905;    link: rlSerial; name: 'IC-905';    maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7100;   link: rlSerial; name: 'IC-7100';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7300;   link: rlSerial; name: 'IC-7300';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7300MK2;link: rlSerial; name: 'IC-7300MK2';maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7410;   link: rlSerial; name: 'IC-7410';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7600;   link: rlSerial; name: 'IC-7600';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7610;   link: rlSerial; name: 'IC-7610';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7700;   link: rlSerial; name: 'IC-7700';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7760;   link: rlSerial; name: 'IC-7760';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7800;   link: rlSerial; name: 'IC-7800';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7850;   link: rlSerial; name: 'IC-7850';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC7851;   link: rlSerial; name: 'IC-7851';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC9100;   link: rlSerial; name: 'IC-9100';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      (model: IC9700;   link: rlSerial; name: 'IC-9700';   maxLen: 28; pad: False; busyPct: 125; skText: '^SK'; snText: '^SN'),
      // Ten-Tec keys with '/<text>', not a KY: no limit, no padding.
      (model: ORION;  link: rlSerial;  name: 'Orion';   maxLen: 0;  pad: False; busyPct: 100; skText: '>';    snText: '%')
   );

   // String-id radios have no InterfacedRadioType, which is the whole reason the
   // model table could not describe them.  Pinned by id.
   TCI_ID = 'TCI';

procedure TCWFramingTests.Test_DeclaredRulesArePinned;
var
   i: integer;
   r: TFactoryRadioBase;
   caps: TRadioCapabilities;
begin
   BeginTest('each radio DECLARES the frame rule the model table used to return');

   for i := Low(CW_PINS) to High(CW_PINS) do
      begin
      r := uRadioRegistry.CreateInstanceForLink(CW_PINS[i].model, CW_PINS[i].link);
      CheckTrue(r <> nil, CW_PINS[i].name + ' constructs');
      if r = nil then
         begin
         Continue;
         end;
      try
         caps := r.Capabilities;
         CheckEquals(CW_PINS[i].maxLen, caps.CWFrame.maxLen,
                     CW_PINS[i].name + ' maxLen');
         CheckTrue(caps.CWFrame.pad = CW_PINS[i].pad,
                   CW_PINS[i].name + ' pad');
         CheckEquals(CW_PINS[i].busyPct, Round(caps.CWFrame.busyFactor * 100),
                     CW_PINS[i].name + ' busyFactor');
         // The radio spells its own prosigns now, so ask it rather than
         // reading a dialect enum off the capability record.
         CheckEquals(CW_PINS[i].skText, r.CWProsign('<').text,
                     CW_PINS[i].name + ' SK spelling');
         CheckEquals(CW_PINS[i].snText, r.CWProsign('!').text,
                     CW_PINS[i].name + ' SN spelling');
         // Every keying radio must have DECLARED a grammar.  An undeclared one
         // answers handled=False and the token is keyed as a literal '!', which
         // is silent, legal and wrong.
         CheckTrue(r.CWProsign('!').handled,
                   CW_PINS[i].name + ' declares a prosign grammar');
      finally
         r.Free;
      end;
      end;

   // TCI: no length limit, and no prosign substitution -- its cw_macros grammar
   // is not one of the three KY dialects and nobody has established what it does
   // with a prosign, so guessing one would be inventing a fact.
   r := uRadioRegistry.CreateInstanceId(TCI_ID);
   CheckTrue(r <> nil, 'TCI constructs (a string-id radio, no enum)');
   if r <> nil then
      begin
      try
         CheckEquals(0, r.Capabilities.CWFrame.maxLen, 'TCI has no stated limit');
         CheckFalse(r.Capabilities.CWFrame.pad, 'TCI does not pad');
         CheckFalse(r.CWProsign('<').handled,
                    'TCI substitutes no prosigns');
         CheckTrue(r.Supports(rcCWByCAT),
                   'TCI can key CW by CAT -- the point of the whole exercise');
      finally
         r.Free;
      end;
      end;
end;

procedure TCWFramingTests.Test_EveryKeyingRadioIsPinned;
var
   m: InterfacedRadioType;
   i: integer;
   found: boolean;
   r: TFactoryRadioBase;
   keys: boolean;
begin
   // The guard that makes the table above worth having: a radio that declares
   // rcCWByCAT without a pin would otherwise be free to inherit a zeroed frame
   // rule -- legal, silent, and wrong on any radio with a real length limit.
   BeginTest('no radio can declare rcCWByCAT without pinning its frame rule');

   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if (m = NoInterfacedRadio) or not uRadioRegistry.IsRegistered(m) then
         begin
         Continue;
         end;
      keys := uRadioRegistry.SupportsFor(m, rcCWByCAT);
      if not keys then
         begin
         Continue;
         end;
      found := False;
      for i := Low(CW_PINS) to High(CW_PINS) do
         begin
         if CW_PINS[i].model = m then
            begin
            found := True;
            Break;
            end;
         end;
      // ModelId is the registry's own enum->id name (RTTI), which avoids pulling
      // LogRadio in just for InterfacedRadioTypeSA.
      CheckTrue(found,
                'model ' + uRadioRegistry.ModelId(m) +
                ' declares rcCWByCAT but has no row in CW_PINS -- state its ' +
                'frame rule in the driver and pin it here');
      end;

   // And the converse: a pinned radio that no longer claims rcCWByCAT means the
   // table has gone stale.
   for i := Low(CW_PINS) to High(CW_PINS) do
      begin
      r := uRadioRegistry.CreateInstanceForLink(CW_PINS[i].model, CW_PINS[i].link);
      if r <> nil then
         begin
         try
            CheckTrue(r.Supports(rcCWByCAT),
                      CW_PINS[i].name + ' is pinned, so it must still claim rcCWByCAT');
         finally
            r.Free;
         end;
         end;
      end;
end;

procedure TCWFramingTests.Test_ChunkingAndPadding;
var
   rule: TCWFrameRule;
   longText: string;
begin
   BeginTest('messages are cut into maxLen chunks, last one padded when required');

   rule := CWFrameRule(22, True);              // the Elecraft rule
   CheckEquals(1, CWChunkCount('CQ TEST NY4I', rule), 'short message -> one chunk');
   CheckEquals(22, Length(CWChunk('CQ TEST NY4I', rule, 1)),
               'a padding rule fills the chunk to maxLen');
   CheckEquals('CQ TEST NY4I          ', CWChunk('CQ TEST NY4I', rule, 1),
               'padding is trailing spaces, text unchanged');

   longText := StringOfChar('A', 50);
   CheckEquals(3, CWChunkCount(longText, rule), '50 chars at 22 -> 3 chunks');
   CheckEquals(StringOfChar('A', 22), CWChunk(longText, rule, 1), 'chunk 1 full');
   CheckEquals(StringOfChar('A', 22), CWChunk(longText, rule, 2), 'chunk 2 full');
   // 50 - 44 = 6 real chars, padded out to 22
   CheckEquals(StringOfChar('A', 6) + StringOfChar(' ', 16),
               CWChunk(longText, rule, 3), 'final chunk padded');

   rule := CWFrameRule(24, False);             // the TS-890 rule
   CheckEquals('CQ TEST', CWChunk('CQ TEST', rule, 1),
               'a non-padding rule sends the text as-is, no fill');
end;

procedure TCWFramingTests.Test_ElementCountUsesUnpaddedText;
var
   rule: TCWFrameRule;
begin
   // Issue 153: the busy timer counts elements on the REAL text.  The radio
   // trims trailing pad spaces instead of keying them, so counting the padded
   // form inflated tmrCWByCAT -- a 1-char '?' padded to 22 counted as 165
   // elements, giving a bogus ~8 s CWByCAT_Sending window.
   BeginTest('the unpadded chunk is available for element counting (Issue 153)');
   rule := CWFrameRule(22, True);
   CheckEquals('?', CWChunkUnpadded('?', rule, 1), 'unpadded keeps the real text');
   CheckEquals(22, Length(CWChunk('?', rule, 1)), 'padded form is what goes on the wire');
end;

procedure TCWFramingTests.Test_EdgeCases;
var
   rule: TCWFrameRule;
   noLimit: TCWFrameRule;
begin
   BeginTest('empty text, out-of-range index, and the no-limit rule');
   rule := CWFrameRule(22, True);
   CheckEquals(0, CWChunkCount('', rule), 'empty text -> no chunks');
   CheckEquals('', CWChunk('', rule, 1), 'no chunk 1 of an empty message');
   CheckEquals('', CWChunk('CQ', rule, 0), 'index 0 is out of range (1-based)');
   CheckEquals('', CWChunk('CQ', rule, 2), 'index past the end is out of range');

   // maxLen 0 means "send it whole" -- must not divide by zero or truncate.
   // This is also what an UNDECLARED rule looks like, which is why the pin
   // tests above exist.
   noLimit := CWFrameRule(0, False);
   CheckEquals(1, CWChunkCount(StringOfChar('A', 500), noLimit),
               'no-limit rule sends one chunk however long');
   CheckEquals(500, Length(CWChunk(StringOfChar('A', 500), noLimit, 1)),
               'no-limit chunk is the whole text, unpadded');

   // The default constructor argument is the common case; only Icom overrides it.
   CheckEquals(100, Round(CWFrameRule(24, True).busyFactor * 100),
               'busyFactor defaults to 1.0');
end;

procedure TCWFramingTests.Test_ProsignsDifferByDialect;
var
   rElecraft, rKenwood: TFactoryRadioBase;
begin
   BeginTest('Elecraft and Kenwood spell the same prosigns differently');

   // Through the RADIO, which is the only way to ask now: there is no dialect
   // enum and no shared spelling function to call directly.
   rElecraft    := uRadioRegistry.CreateInstanceForLink(K3, rlSerial);
   rKenwood := uRadioRegistry.CreateInstanceForLink(TS570, rlSerial);
   CheckTrue((rElecraft <> nil) and (rKenwood <> nil), 'both radios construct');
   if (rElecraft = nil) or (rKenwood = nil) then
      begin
      Exit;
      end;
   try
      CheckEquals('+', rElecraft.CWProsign('+').text, 'Elecraft AR');
      CheckEquals('_', rKenwood.CWProsign('+').text, 'Kenwood AR');
      CheckEquals('*', rElecraft.CWProsign('<').text, 'Elecraft SK');
      CheckEquals('>', rKenwood.CWProsign('<').text, 'Kenwood SK');
      CheckEquals('=', rElecraft.CWProsign('=').text, 'Elecraft BT');
      CheckEquals('[', rKenwood.CWProsign('=').text, 'Kenwood BT');

      // Half space: neither KY grammar has one, so both key a whole space.
      CheckEquals(' ', rElecraft.CWProsign('^').text, 'Elecraft half space -> space');
      CheckEquals(' ', rKenwood.CWProsign('^').text, 'Kenwood half space -> space');

      // SN exists on Kenwood only.  On Elecraft the token is still HANDLED --
      // it must not fall through and be keyed as a literal '!' -- but produces
      // no text.  A declared-but-empty spelling is not an undeclared grammar.
      CheckEquals('%', rKenwood.CWProsign('!').text, 'Kenwood SN');
      CheckTrue(rElecraft.CWProsign('!').handled, 'Elecraft SN token is consumed');
      CheckEquals('', rElecraft.CWProsign('!').text, 'Elecraft has no SN, keys nothing');

      // Anything else is not a prosign: the caller keys it as literal text.
      CheckFalse(rElecraft.CWProsign('A').handled, 'a letter is not a prosign');
      CheckFalse(rElecraft.CWProsign('&').handled, 'AS is deliberately not handled');
      CheckFalse(rElecraft.CWProsign('').handled, 'empty token is not a prosign');
      CheckFalse(rElecraft.CWProsign('CQ').handled, 'a whole word is not a prosign');
   finally
      rElecraft.Free;
      rKenwood.Free;
   end;
end;

procedure TCWFramingTests.Test_IcomIsAThirdDialect;
var
   rIcom: TFactoryRadioBase;
begin
   BeginTest('Icom keys prosigns as run-together ASCII, not substitute characters');

   // Icom has no prosign alphabet.  '^' (0x5E) is a MODIFIER meaning "no
   // inter-character space", so '^SK' is the letters S and K keyed together --
   // which IS SK.  The documented character table is 20, 27-3F and 41-7A.
   rIcom := uRadioRegistry.CreateInstanceForLink(IC7300, rlSerial);
   CheckTrue(rIcom <> nil, 'IC-7300 constructs');
   if rIcom = nil then
      begin
      Exit;
      end;
   try
      CheckEquals('^AR', rIcom.CWProsign('+').text, 'Icom AR');
      CheckEquals('^SK', rIcom.CWProsign('<').text, 'Icom SK');
      CheckEquals('^BT', rIcom.CWProsign('=').text, 'Icom BT');
      CheckEquals('^SN', rIcom.CWProsign('!').text, 'Icom SN');

      // WHY IT CANNOT BORROW EITHER KY GRAMMAR: every character those
      // substitute is outside the set Icom accepts for command $17.
      CheckTrue(Pos('*', '%_*>[') > 0, 'Elecraft SK is one of the illegal five');
      CheckTrue(Pos('>', '%_*>[') > 0, 'Kenwood SK is one of the illegal five');

      // TR4W's '^' is a HALF space; Icom's '^' is the no-space modifier.
      // Passing the token through would run the next two characters together.
      CheckEquals(' ', rIcom.CWProsign('^').text, 'Icom half space -> space, NOT a bare ^');

      CheckFalse(rIcom.CWProsign('A').handled, 'a letter is not a prosign on Icom either');
   finally
      rIcom.Free;
   end;

   // Icom's own length limit, previously a truncation at 28 in LOGRADIO.
   CheckEquals(2, CWChunkCount(StringOfChar('A', 40), CWFrameRule(28, False)),
               '40 chars is two Icom commands, not a silent truncation');
end;

procedure TCWFramingTests.Test_NoneDialectPassesEverythingThrough;
var
   t: string;
   r: TFactoryRadioBase;
begin
   // A radio whose CW grammar nobody has established must substitute NOTHING:
   // every token comes back unhandled so the caller keys it literally.  Sending
   // an untested radio another vendor's substitute characters would be a guess
   // presented as a fact.  This is the base-class default, and TCI relies on it.
   BeginTest('an undeclared grammar substitutes nothing -- tokens pass through');
   r := uRadioRegistry.CreateInstanceId(TCI_ID);
   CheckTrue(r <> nil, 'TCI constructs');
   if r = nil then
      begin
      Exit;
      end;
   try
      for t in ['^', '!', '+', '<', '=', 'A', 'CQ', ''] do
         begin
         CheckFalse(r.CWProsign(t).handled,
                    'an undeclared grammar leaves "' + t + '" to the caller');
         CheckEquals('', r.CWProsign(t).text,
                     'no text is substituted for "' + t + '"');
         end;
   finally
      r.Free;
   end;
end;


procedure TCWFramingTests.RunAllTests;
begin
   Test_DeclaredRulesArePinned;
   Test_EveryKeyingRadioIsPinned;
   Test_ChunkingAndPadding;
   Test_ElementCountUsesUnpaddedText;
   Test_EdgeCases;
   Test_ProsignsDifferByDialect;
   Test_IcomIsAThirdDialect;
   Test_NoneDialectPassesEverythingThrough;
end;

end.

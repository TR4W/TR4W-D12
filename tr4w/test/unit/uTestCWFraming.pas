unit uTestCWFraming;

{
  Pins the per-model CW-by-CAT framing rules extracted into uCWFraming.

  These rules are BENCH-DERIVED FACTS about real radios -- particularly the
  K3/K4 padding rule, which exists because of a specific 2026-06-18 finding
  (a short KY is swallowed by the keyer-abort window that precedes it).  They
  were previously buried in LOGRADIO's CW case statement where nothing could
  test them; being pure string manipulation, they can be pinned offline, so a
  future refactor cannot quietly lose one.
}

interface

uses
   SysUtils, uTR4WTestFramework, uCWFraming, VC;

type
   TCWFramingTests = class(TTestCase)
   protected
      procedure Test_PerModelRules;
      procedure Test_FlexTransportDiffers;
      procedure Test_ChunkingAndPadding;
      procedure Test_ElementCountUsesUnpaddedText;
      procedure Test_EdgeCases;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TCWFramingTests.Test_PerModelRules;
var
   r: TCWFrameRule;
begin
   BeginTest('per-model maxLen/pad match the rules LOGRADIO shipped');

   r := CWFrameRuleFor(TS890, False);
   CheckEquals(24, r.maxLen, 'TS-890 maxLen');
   CheckFalse(r.pad, 'TS-890 takes a variable-length P2 -- no 24-byte fill');

   r := CWFrameRuleFor(TS570, False);
   CheckEquals(24, r.maxLen, 'Kenwood maxLen');
   CheckTrue(r.pad, 'the other Kenwoods reject a short P2 under P1=space');

   r := CWFrameRuleFor(K2, False);
   CheckEquals(22, r.maxLen, 'K2 maxLen');
   CheckFalse(r.pad, 'K2 does not need the abort-window runway');

   r := CWFrameRuleFor(K3, False);
   CheckEquals(22, r.maxLen, 'K3 maxLen');
   CheckTrue(r.pad, 'K3/KX3/K4 pad to survive the keyer-abort window (2026-06-18)');
   CheckTrue(CWFrameRuleFor(KX3, False).pad, 'KX3 same as K3');
   CheckTrue(CWFrameRuleFor(K4, False).pad, 'K4 same as K3');

   // A radio with no CW-by-CAT at all: rule is "no limit", and the chunker
   // must not invent one.
   r := CWFrameRuleFor(FT1000MP, False);
   CheckEquals(0, r.maxLen, 'a non-CW-by-CAT radio has no length rule');
end;

procedure TCWFramingTests.Test_FlexTransportDiffers;
var
   net, ser: TCWFrameRule;
begin
   // The one model whose rule depends on the TRANSPORT: the Ethernet API's cwx
   // send has no padding requirement; the serial CAT KY path behaves Kenwood-like.
   BeginTest('Flex padding depends on transport (network cwx vs serial KY)');
   net := CWFrameRuleFor(FLEX, True);
   ser := CWFrameRuleFor(FLEX, False);
   CheckFalse(net.pad, 'Flex over the Ethernet API does not pad');
   CheckTrue(ser.pad, 'Flex over serial CAT pads like a Kenwood');
end;

procedure TCWFramingTests.Test_ChunkingAndPadding;
var
   rule: TCWFrameRule;
   longText: string;
begin
   BeginTest('messages are cut into maxLen chunks, last one padded when required');

   rule := CWFrameRuleFor(K3, False);          // 22, pad
   CheckEquals(1, CWChunkCount('CQ TEST NY4I', rule), 'short message -> one chunk');
   CheckEquals(22, Length(CWChunk('CQ TEST NY4I', rule, 1)),
               'K3 pads the chunk to maxLen');
   CheckEquals('CQ TEST NY4I          ', CWChunk('CQ TEST NY4I', rule, 1),
               'padding is trailing spaces, text unchanged');

   longText := StringOfChar('A', 50);
   CheckEquals(3, CWChunkCount(longText, rule), '50 chars at 22 -> 3 chunks');
   CheckEquals(StringOfChar('A', 22), CWChunk(longText, rule, 1), 'chunk 1 full');
   CheckEquals(StringOfChar('A', 22), CWChunk(longText, rule, 2), 'chunk 2 full');
   // 50 - 44 = 6 real chars, padded out to 22
   CheckEquals(StringOfChar('A', 6) + StringOfChar(' ', 16),
               CWChunk(longText, rule, 3), 'final chunk padded');

   rule := CWFrameRuleFor(TS890, False);       // 24, no pad
   CheckEquals('CQ TEST', CWChunk('CQ TEST', rule, 1),
               'TS-890 sends the text as-is, no fill');
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
   rule := CWFrameRuleFor(K3, False);
   CheckEquals('?', CWChunkUnpadded('?', rule, 1), 'unpadded keeps the real text');
   CheckEquals(22, Length(CWChunk('?', rule, 1)), 'padded form is what goes on the wire');
end;

procedure TCWFramingTests.Test_EdgeCases;
var
   rule: TCWFrameRule;
   noLimit: TCWFrameRule;
begin
   BeginTest('empty text, out-of-range index, and the no-limit rule');
   rule := CWFrameRuleFor(K3, False);
   CheckEquals(0, CWChunkCount('', rule), 'empty text -> no chunks');
   CheckEquals('', CWChunk('', rule, 1), 'no chunk 1 of an empty message');
   CheckEquals('', CWChunk('CQ', rule, 0), 'index 0 is out of range (1-based)');
   CheckEquals('', CWChunk('CQ', rule, 2), 'index past the end is out of range');

   // maxLen 0 means "send it whole" -- must not divide by zero or truncate.
   noLimit := CWFrameRuleFor(FT1000MP, False);
   CheckEquals(1, CWChunkCount(StringOfChar('A', 500), noLimit),
               'no-limit rule sends one chunk however long');
   CheckEquals(500, Length(CWChunk(StringOfChar('A', 500), noLimit, 1)),
               'no-limit chunk is the whole text, unpadded');
end;

procedure TCWFramingTests.RunAllTests;
begin
   Test_PerModelRules;
   Test_FlexTransportDiffers;
   Test_ChunkingAndPadding;
   Test_ElementCountUsesUnpaddedText;
   Test_EdgeCases;
end;

end.

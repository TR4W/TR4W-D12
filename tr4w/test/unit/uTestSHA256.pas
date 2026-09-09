unit uTestSHA256;
{$I ..\..\src\tr4w.inc}

(*
  SHA-256 AGAINST THE PUBLISHED VECTORS, NOT AGAINST ITSELF.

  NONE of these digests was produced by running this implementation. That is
  the failure mode a hash test invites -- an implementation compared against
  its own output is a test that a broken hash passes -- so the provenance is
  stated rather than assumed:

    abc, the 56-character vector, and the million characters come from
    FIPS 180-2 Appendix B, the standard's own worked examples.

    the empty message and the two fox strings are the widely published values.

    the block-boundary digests were computed with Python's hashlib, an
    INDEPENDENT implementation, because no standard publishes a vector at 55
    or 64 bytes and a remembered value is not evidence.

  All twelve were cross-checked against hashlib before being written down.

  WHY A HAND-WRITTEN HASH IS TESTABLE AT ALL, and why writing one was
  acceptable under the rule that says prefer the RTL: SHA-256 is completely
  specified and will never change, so it can be PINNED rather than trusted.
  Neither FPC 3.2.2 nor Lazarus ships one -- both were checked -- and the
  alternative was a dependency for a single digest.

  THE CASES THAT EARN THEIR KEEP are the ones that exercise the padding
  arithmetic, because that is the only part where a plausible-looking
  implementation goes wrong and a short-string test still passes:

    the empty message         padding with no data at all
    55 bytes                  the last length that fits its padding in ONE block
    56 bytes                  the first that does NOT -- spills to a second
    64 bytes                  exactly one block, so padding is a whole extra one
    1,000,000 bytes           15,625 blocks, and the 64-bit length field
*)

interface

uses
   uTR4WTestFramework;

type
   TSHA256Tests = class(TTestCase)
   protected
      procedure Test_FIPSVectors;
      procedure Test_BlockBoundaries;
      procedure Test_MillionCharacters;
      procedure Test_StreamMatchesBytes;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, uSHA256;

procedure TSHA256Tests.Test_FIPSVectors;
begin
   BeginTest('the published FIPS 180-2 and RFC 6234 vectors');

   // FIPS 180-2 B.1 -- one block
   CheckEquals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
               SHA256OfBytes('abc'), 'abc');

   // FIPS 180-2 B.2 -- two blocks
   CheckEquals('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
               SHA256OfBytes('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
               'the 56-character multi-block vector');

   // RFC 6234 -- the empty message, which is padding and nothing else
   CheckEquals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
               SHA256OfBytes(''), 'the empty message');

   // Widely published; catches a byte-order slip that the short vectors miss
   CheckEquals('d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
               SHA256OfBytes('The quick brown fox jumps over the lazy dog'),
               'the quick brown fox');

   // The same text with one character changed -- an avalanche check, so a
   // hash that ignored part of its input cannot pass both.
   CheckEquals('ef537f25c895bfa782526529a9b63d97aa631564d5d789c2b765448c8635fb6c',
               SHA256OfBytes('The quick brown fox jumps over the lazy dog.'),
               'the quick brown fox, with a full stop');
end;

procedure TSHA256Tests.Test_BlockBoundaries;
var
   s: RawByteString;
begin
   BeginTest('the lengths where the padding changes shape');

   (* 55 BYTES: the largest message whose padding and 8-byte length still fit
     in the same 64-byte block. *)
   s := StringOfChar(AnsiChar('a'), 55);
   CheckEquals('9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318',
               SHA256OfBytes(s), '55 bytes -- one block');

   (* 56 BYTES: one more, and the length no longer fits, so a SECOND block is
     required. An implementation that pads to 56 mod 64 without handling the
     spill produces a wrong digest here and a right one everywhere shorter. *)
   s := StringOfChar(AnsiChar('a'), 56);
   CheckEquals('b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a',
               SHA256OfBytes(s), '56 bytes -- spills into a second block');

   (* 63, 64 and 65: either side of an exact block. At 64 the message fills a
     block exactly and the padding is a whole additional one. *)
   s := StringOfChar(AnsiChar('a'), 63);
   CheckEquals('7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34',
               SHA256OfBytes(s), '63 bytes');

   s := StringOfChar(AnsiChar('a'), 64);
   CheckEquals('ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb',
               SHA256OfBytes(s), '64 bytes -- exactly one block');

   s := StringOfChar(AnsiChar('a'), 65);
   CheckEquals('635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0',
               SHA256OfBytes(s), '65 bytes');
end;

procedure TSHA256Tests.Test_MillionCharacters;
var
   s: RawByteString;
begin
   (* FIPS 180-2 B.3. Fifteen thousand blocks, and the only case here where the
     64-bit length field carries a value that does not fit in 32 bits worth of
     BITS -- 8,000,000 does fit, but the accumulation path is the same one that
     would overflow, and this is the standard's own check of it. *)
   BeginTest('one million characters -- the FIPS 180-2 long vector');

   s := StringOfChar(AnsiChar('a'), 1000000);
   CheckEquals('cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
               SHA256OfBytes(s), 'a million as');
end;

procedure TSHA256Tests.Test_StreamMatchesBytes;
var
   s:  RawByteString;
   ms: TMemoryStream;
begin
   (* THE TWO ENTRY POINTS MUST AGREE. The stream path reads in 64 KB chunks,
     so it takes a different route through Update than a single call does --
     the chunk boundary does not fall on a block boundary, which is exactly
     where a buffering error hides. The file the SCP upload hashes goes through
     the stream path; the shared secret goes through the byte path. *)
   BeginTest('the stream and byte entry points agree');

   s := '';
   while Length(s) < 200000 do
      begin
      s := s + 'The quick brown fox jumps over the lazy dog. 0123456789';
      end;

   ms := TMemoryStream.Create;
   try
      ms.WriteBuffer(s[1], Length(s));
      ms.Position := 0;
      CheckEquals(SHA256OfBytes(s), SHA256OfStream(ms),
                  'a 200 KB message hashes the same either way');
   finally
      ms.Free;
   end;
end;

procedure TSHA256Tests.RunAllTests;
begin
   Test_FIPSVectors;
   Test_BlockBoundaries;
   Test_MillionCharacters;
   Test_StreamMatchesBytes;
end;

end.

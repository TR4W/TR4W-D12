unit uSHA256;
{$I ..\tr4w.inc}
(*
  SHA-256, FIPS 180-4, in Pascal and depending on nothing.

  WHY THIS UNIT EXISTS AT ALL.

  TR4W needs SHA-256 in exactly one place: the SuperCheckPartial upload hashes
  the Cabrillo file and a shared secret so the server can tell that a
  submission is genuine. That hash used to come from Indy's TIdHashSHA256.

  INDY'S SHA-256 IS NOT A HASH, IT IS AN OpenSSL CALL. TIdHashSHA256.IsAvailable
  returns False unless Indy has loaded OpenSSL, and Indy 10.6.3.3 cannot load
  OpenSSL 3 -- it finds the library and refuses the version. So on any current
  Linux the upload failed with

      SHA256 is not available to this instance of Indy - CheckOpenSSL dlls
      are available

  which NY4I hit on Linux Mint (2026-09-09) simply by writing a Cabrillo file.
  A digest of some bytes has no business depending on a TLS library being
  loadable, and that coupling is the actual defect.

  NEITHER FPC 3.2.2 NOR LAZARUS SHIPS ONE. The RTL has md5 and sha1 and stops
  there; nothing under components has SHA-256 either. Both were checked before
  this was written, because the rule in CLAUDE.md is to reach for the RTL
  first and justify writing anything.

  SO IT IS WRITTEN OUT, and that is a smaller thing than it sounds: SHA-256 is
  a fully specified, unchanging algorithm with published test vectors, so it
  can be pinned exactly rather than trusted. test\unit\uTestSHA256 checks it
  against the FIPS 180-2 and RFC 6234 vectors including the million-character
  one, which exercises the multi-block path that a short string never reaches.

  The alternative was a dependency, and a dependency for one hash costs more
  than a hundred lines that cannot drift.
*)

interface

uses
   Classes;

(* Lower-case hex, 64 characters. Takes BYTES: a digest is defined over bytes,
  and leaving the encoding to the caller is what stops the same text hashing
  two ways on two platforms. *)
function SHA256OfBytes(const aBytes: RawByteString): string;

(* The whole stream from its current position, read in blocks rather than
  loaded, so a Cabrillo file of any size costs one buffer. *)
function SHA256OfStream(aStream: TStream): string;

function SHA256OfFile(const aPath: string): string;

implementation

uses
   SysUtils;

type
   TSHA256State = record
      H:      array[0..7] of LongWord;
      Buffer: array[0..63] of Byte;
      Used:   integer;    (* bytes currently in Buffer *)
      Length: QWord;      (* total message length in BYTES *)
   end;

const
   (* The first 32 bits of the fractional parts of the cube roots of the first
     64 primes -- FIPS 180-4 section 4.2.2, verbatim. *)
   K: array[0..63] of LongWord = (
      $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5,
      $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
      $d807aa98, $12835b01, $243185be, $550c7dc3,
      $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
      $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc,
      $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
      $983e5152, $a831c66d, $b00327c8, $bf597fc7,
      $c6e00bf3, $d5a79147, $06ca6351, $14292967,
      $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13,
      $650a7354, $766a0abb, $81c2c92e, $92722c85,
      $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3,
      $d192e819, $d6990624, $f40e3585, $106aa070,
      $19a4c116, $1e376c08, $2748774c, $34b0bcb5,
      $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
      $748f82ee, $78a5636f, $84c87814, $8cc70208,
      $90befffa, $a4506ceb, $bef9a3f7, $c67178f2);

(* Rotate right. Written out rather than assumed: FPC has RorDWord, but a
  three-token expression that is provably correct beats an intrinsic the
  reader has to go and check. *)
function RotR(const aValue: LongWord; const aBits: Byte): LongWord; inline;
begin
   Result := (aValue shr aBits) or (aValue shl (32 - aBits));
end;

procedure SHA256Init(out aState: TSHA256State);
begin
   (* The first 32 bits of the fractional parts of the square roots of the
     first eight primes -- FIPS 180-4 section 5.3.3. *)
   aState.H[0] := $6a09e667;
   aState.H[1] := $bb67ae85;
   aState.H[2] := $3c6ef372;
   aState.H[3] := $a54ff53a;
   aState.H[4] := $510e527f;
   aState.H[5] := $9b05688c;
   aState.H[6] := $1f83d9ab;
   aState.H[7] := $5be0cd19;
   aState.Used   := 0;
   aState.Length := 0;
   FillChar(aState.Buffer, SizeOf(aState.Buffer), 0);
end;

(* One 64-byte block. BIG-ENDIAN ON THE WAY IN, which is the whole of what
  makes this portable: the standard defines the message as a sequence of
  big-endian words, and reading the buffer as native LongWords would give a
  different digest on a little-endian machine. *)
procedure SHA256Block(var aState: TSHA256State; const aBlock: array of Byte);
var
   w: array[0..63] of LongWord;
   a, b, c, d, e, f, g, h: LongWord;
   s0, s1, ch, maj, t1, t2: LongWord;
   i: integer;
begin
   for i := 0 to 15 do
      begin
      w[i] := (LongWord(aBlock[i * 4    ]) shl 24) or
              (LongWord(aBlock[i * 4 + 1]) shl 16) or
              (LongWord(aBlock[i * 4 + 2]) shl 8)  or
               LongWord(aBlock[i * 4 + 3]);
      end;

   for i := 16 to 63 do
      begin
      s0 := RotR(w[i - 15], 7) xor RotR(w[i - 15], 18) xor (w[i - 15] shr 3);
      s1 := RotR(w[i - 2], 17) xor RotR(w[i - 2], 19) xor (w[i - 2] shr 10);
      w[i] := w[i - 16] + s0 + w[i - 7] + s1;
      end;

   a := aState.H[0];
   b := aState.H[1];
   c := aState.H[2];
   d := aState.H[3];
   e := aState.H[4];
   f := aState.H[5];
   g := aState.H[6];
   h := aState.H[7];

   for i := 0 to 63 do
      begin
      s1  := RotR(e, 6) xor RotR(e, 11) xor RotR(e, 25);
      ch  := (e and f) xor ((not e) and g);
      t1  := h + s1 + ch + K[i] + w[i];
      s0  := RotR(a, 2) xor RotR(a, 13) xor RotR(a, 22);
      maj := (a and b) xor (a and c) xor (b and c);
      t2  := s0 + maj;

      h := g;
      g := f;
      f := e;
      e := d + t1;
      d := c;
      c := b;
      b := a;
      a := t1 + t2;
      end;

   Inc(aState.H[0], a);
   Inc(aState.H[1], b);
   Inc(aState.H[2], c);
   Inc(aState.H[3], d);
   Inc(aState.H[4], e);
   Inc(aState.H[5], f);
   Inc(aState.H[6], g);
   Inc(aState.H[7], h);
end;

procedure SHA256Update(var aState: TSHA256State; const aData; const aCount: integer);
var
   p:    PByte;
   left: integer;
   take: integer;
begin
   if aCount <= 0 then
      begin
      Exit;
      end;

   p := @aData;
   left := aCount;
   Inc(aState.Length, QWord(aCount));

   while left > 0 do
      begin
      take := 64 - aState.Used;
      if take > left then
         begin
         take := left;
         end;

      Move(p^, aState.Buffer[aState.Used], take);
      Inc(aState.Used, take);
      Inc(p, take);
      Dec(left, take);

      if aState.Used = 64 then
         begin
         SHA256Block(aState, aState.Buffer);
         aState.Used := 0;
         end;
      end;
end;

function SHA256Final(var aState: TSHA256State): string;
const
   HEX: array[0..15] of Char = ('0','1','2','3','4','5','6','7',
                                '8','9','a','b','c','d','e','f');
var
   bits: QWord;
   pad:  array[0..63] of Byte;
   i:    integer;
   n:    integer;
   v:    Byte;
begin
   (* The length is appended in BITS, big-endian, and it is the length of the
     message -- captured before any padding is added. *)
   bits := aState.Length * 8;

   FillChar(pad, SizeOf(pad), 0);
   pad[0] := $80;

   (* Pad to 56 mod 64, leaving room for the 8-byte length. When Used is
     already 56..63 this spills into a second block, which is correct and is
     the case a one-block test never reaches. *)
   if aState.Used < 56 then
      begin
      n := 56 - aState.Used;
      end
   else
      begin
      n := 120 - aState.Used;
      end;
   SHA256Update(aState, pad, n);

   (* SHA256Update counted those padding bytes into Length, which must not
     affect the value written here -- hence bits was taken above. *)
   for i := 7 downto 0 do
      begin
      v := Byte((bits shr (i * 8)) and $FF);
      SHA256Update(aState, v, 1);
      end;

   SetLength(Result, 64);
   for i := 0 to 7 do
      begin
      Result[i * 8 + 1] := HEX[(aState.H[i] shr 28) and $F];
      Result[i * 8 + 2] := HEX[(aState.H[i] shr 24) and $F];
      Result[i * 8 + 3] := HEX[(aState.H[i] shr 20) and $F];
      Result[i * 8 + 4] := HEX[(aState.H[i] shr 16) and $F];
      Result[i * 8 + 5] := HEX[(aState.H[i] shr 12) and $F];
      Result[i * 8 + 6] := HEX[(aState.H[i] shr 8)  and $F];
      Result[i * 8 + 7] := HEX[(aState.H[i] shr 4)  and $F];
      Result[i * 8 + 8] := HEX[ aState.H[i]         and $F];
      end;
end;

function SHA256OfBytes(const aBytes: RawByteString): string;
var
   st: TSHA256State;
begin
   SHA256Init(st);
   if System.Length(aBytes) > 0 then
      begin
      SHA256Update(st, aBytes[1], System.Length(aBytes));
      end;
   Result := SHA256Final(st);
end;

function SHA256OfStream(aStream: TStream): string;
const
   CHUNK = 64 * 1024;
var
   st:  TSHA256State;
   buf: array of Byte;
   n:   integer;
begin
   SHA256Init(st);
   SetLength(buf, CHUNK);
   repeat
      n := aStream.Read(buf[0], CHUNK);
      if n > 0 then
         begin
         SHA256Update(st, buf[0], n);
         end;
   until n <= 0;
   Result := SHA256Final(st);
end;

function SHA256OfFile(const aPath: string): string;
var
   fs: TFileStream;
begin
   fs := TFileStream.Create(aPath, fmOpenRead or fmShareDenyNone);
   try
      Result := SHA256OfStream(fs);
   finally
      fs.Free;
   end;
end;

end.

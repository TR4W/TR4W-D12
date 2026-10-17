unit uTestCPUKeyerRing;
{$I ..\..\src\tr4w.inc}

(* THE CPU (DTR/RTS) KEYER'S ELEMENT RING -- what LogK1EA.K1EAKeyer turns text
  into before CWThreadProc keys it. Pointer audit packet P6, defect D4
  (docs/POINTER_AUDIT.md).

  WHAT IS PINNED. Every element AddCharacterToCWBuffer and AddStringToCWBuffer
  write, read back out of the ring by index: its length in tenths of a dit and
  whether the line is keyed. The letters, digits and punctuation are checked
  against INTERNATIONAL MORSE written out below as dots and dashes -- an
  independent statement of the answer, not a copy of the case statement --
  so a dropped Dit or a swapped arm fails here, not on the air.

  WHY IT EXISTS. The ring used to be a heap block, CWBuffer: ^array, allocated
  lazily by New() in Dit, Dah, Dat and AddStringToCWBuffer and never disposed.
  The space, '^', control-character and unmapped-character arms wrote through
  it WITHOUT that check, and TCWKeyerCPU.SendChar reaches
  AddCharacterToCWBuffer directly -- so a session whose first autosend
  character was a space wrote to address 0 (D4). The ring is now a fixed array
  field of the keyer: no heap, no nil, nothing to leak.
  Test_SpaceFirstWritesAGap is that case, and it is FIRST in RunAllTests on
  purpose: against the old code it only reached nil when no earlier keying had
  happened to allocate the block.

  NO HARDWARE, NO THREAD. Nothing here opens a port or starts CWThreadProc; the
  ring is filled and read, never keyed. Every test saves and restores the ring
  indices and the settings it changes, so test order cannot leak state. *)

interface

uses
   SysUtils,
   uTR4WTestFramework,
   LogK1EA,          (* CPUKeyer, CWBufferStart/End, CWBufferSize, MonitorTone *)
   uSettingsModel,   (* Settings.Cw.DitDahRatio, .StartSendingNowKey *)
   MainUnit,         (* logger -- AddCharacterToCWBuffer logs every character *)
   VC;               (* ControlE .. ControlY, ControlLeftBracket *)

type
   TCPUKeyerRingTests = class(TTestCase)
   protected
      procedure CheckMorse(ch: Char; const pattern: string);
      procedure Test_SpaceFirstWritesAGap;
      procedure Test_LettersAndDigitsAreInternationalMorse;
      procedure Test_PunctuationAndProsigns;
      procedure Test_LowerCaseIsUpperCase;
      procedure Test_SpacingAndUnkeyedCharacters;
      procedure Test_ControlCharacters;
      procedure Test_DahLengthFollowsTheSetting;
      procedure Test_AddStringToCWBuffer;
      procedure Test_RingWrapsAtBufferSize;
      procedure Test_DeleteLastCharacter;
      procedure Test_DeleteLastCharacterAtEndZero;
      procedure Test_RingSlotArithmetic;
      procedure Test_FlushedStartStopsInOneStep;
      procedure Test_RingIsOwnedByTheKeyer;
      procedure Test_FeedingTheRingAllocatesNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   (* What a test changes, so it can be put back. *)
   TRingState = record
      BufferStart: integer;
      BufferEnd: integer;
      Tone: integer;
      Ratio: TCwDitDahRatio;
      StartKey: Char;
   end;

const
   (* The start-sending-now key for these tests: printable, mapped by no
     Morse arm, and used nowhere else below. *)
   TEST_START_KEY = '~';

function SaveRing: TRingState;
begin
   Result.BufferStart := CWBufferStart;
   Result.BufferEnd := CWBufferEnd;
   Result.Tone := MonitorTone;
   Result.Ratio := Settings.Cw.DitDahRatio;
   Result.StartKey := Settings.Cw.StartSendingNowKey;
   (* The fixture every test starts from: an empty ring, a 3:1 dah, and a
     start key that is not in any test string. *)
   CWBufferStart := CWBufferEnd;
   Settings.Cw.DitDahRatio := 3;
   Settings.Cw.StartSendingNowKey := TEST_START_KEY;
end;

procedure RestoreRing(const saved: TRingState);
begin
   CWBufferStart := saved.BufferStart;
   CWBufferEnd := saved.BufferEnd;
   MonitorTone := saved.Tone;
   Settings.Cw.DitDahRatio := saved.Ratio;
   Settings.Cw.StartSendingNowKey := saved.StartKey;
end;

(* The elements from index fromIndex up to (not including) CWBufferEnd, walked
  the way CWThreadProc walks them -- modulo CWBufferSize. Each is 'K<n>' if
  the line is keyed for n tenths of a dit, 'U<n>' if it is not. *)
function RingText(fromIndex: integer): string;
var
   i: integer;
   element: CWElementRecord;
begin
   Result := '';
   i := fromIndex;
   while i <> CWBufferEnd do
      begin
      element := CPUKeyer.BufferedElement(i);
      if Result <> '' then
         begin
         Result := Result + ' ';
         end;
      if element.Key then
         begin
         Result := Result + 'K' + SysUtils.IntToStr(element.length);
         end
      else
         begin
         Result := Result + 'U' + SysUtils.IntToStr(element.length);
         end;
      i := (i + 1) mod CWBufferSize;
      end;
end;

(* What one character keys, from its dots and dashes: a dit is 10 keyed and
  10 unkeyed, a dah DahLength keyed and 10 unkeyed, and every printable
  character ends with the 20-tenth inter-character gap. *)
function ExpectedFromMorse(const pattern: string; dahLength: integer): string;
var
   i: integer;
begin
   Result := '';
   for i := 1 to Length(pattern) do
      begin
      if pattern[i] = '.' then
         begin
         Result := Result + 'K10 U10 ';
         end
      else
         begin
         Result := Result + 'K' + SysUtils.IntToStr(dahLength) + ' U10 ';
         end;
      end;
   Result := Result + 'U20';
end;

(* Feed one character on an empty ring and return what it wrote. *)
function KeyedBy(ch: Char): string;
var
   mark: integer;
begin
   mark := CWBufferEnd;
   CPUKeyer.AddCharacterToCWBuffer(ch);
   Result := RingText(mark);
end;

procedure TCPUKeyerRingTests.CheckMorse(ch: Char; const pattern: string);
begin
   CheckEquals(ExpectedFromMorse(pattern, 30), KeyedBy(ch),
                    SysUtils.Format('character #%d (%s) keys %s', [Ord(ch), string(ch), pattern]));
end;

procedure TCPUKeyerRingTests.Test_SpaceFirstWritesAGap;
var
   saved: TRingState;
   written: string;
begin
   (* D4. Against the old code this was a write through a nil CWBuffer when
     nothing earlier in the process had keyed a Dit or a Dah. *)
   BeginTest('D4: a space as the very first character writes one 30-tenth gap, not nil');
   saved := SaveRing;
   try
      try
         written := KeyedBy(' ');
      except
         on E: Exception do
            begin
            written := 'raised ' + string(E.ClassName) + ': ' + E.Message;
            end;
      end;
      CheckEquals('U30', written, 'a word space is one unkeyed element of 30');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_LettersAndDigitsAreInternationalMorse;
const
   LETTERS: array['A'..'Z'] of string = (
      '.-', '-...', '-.-.', '-..', '.', '..-.', '--.', '....', '..', '.---',
      '-.-', '.-..', '--', '-.', '---', '.--.', '--.-', '.-.', '...', '-',
      '..-', '...-', '.--', '-..-', '-.--', '--..');
   DIGITS: array['0'..'9'] of string = (
      '-----', '.----', '..---', '...--', '....-',
      '.....', '-....', '--...', '---..', '----.');
var
   saved: TRingState;
   c: AnsiChar;
begin
   BeginTest('A..Z and 0..9 key international Morse, each followed by a 20-tenth gap');
   saved := SaveRing;
   try
      for c := 'A' to 'Z' do
         begin
         CheckMorse(Char(c), LETTERS[c]);
         end;
      for c := '0' to '9' do
         begin
         CheckMorse(Char(c), DIGITS[c]);
         end;
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_PunctuationAndProsigns;
var
   saved: TRingState;
begin
   BeginTest('punctuation and prosigns: . , ? / and AR (+), SK (<), BT (=), SN (!)');
   saved := SaveRing;
   try
      CheckMorse('.', '.-.-.-');
      CheckMorse(',', '--..--');
      CheckMorse('?', '..--..');
      CheckMorse('/', '-..-.');
      CheckMorse('+', '.-.-.');
      CheckMorse('<', '...-.-');
      CheckMorse('=', '-...-');
      CheckMorse('!', '...-.');
      (* The three accented letters, each under all four of its codes. *)
      CheckMorse(Char(197), '.--.-');
      CheckMorse(Char(229), '.--.-');
      CheckMorse(Char(134), '.--.-');
      CheckMorse(Char(143), '.--.-');
      CheckMorse(Char(196), '.-.-');
      CheckMorse(Char(228), '.-.-');
      CheckMorse(Char(132), '.-.-');
      CheckMorse(Char(142), '.-.-');
      CheckMorse(Char(214), '---.');
      CheckMorse(Char(246), '---.');
      CheckMorse(Char(148), '---.');
      CheckMorse(Char(153), '---.');
      (* '-' is the long dash Dat: 45 keyed, then the usual 10 and the gap. *)
      CheckEquals('K45 U10 U20', KeyedBy('-'), '- keys one 45-tenth element (Dat)');
      (* '&' exits before the gap -- it keys nothing at all. *)
      CheckEquals('', KeyedBy('&'), '& keys nothing, not even a gap');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_LowerCaseIsUpperCase;
var
   saved: TRingState;
begin
   BeginTest('lower case keys exactly what upper case does');
   saved := SaveRing;
   try
      CheckEquals(KeyedBy('Q'), KeyedBy('q'), 'q = Q');
      CheckEquals(KeyedBy('Z'), KeyedBy('z'), 'z = Z');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_SpacingAndUnkeyedCharacters;
var
   saved: TRingState;
begin
   BeginTest('space, half space, an unmapped character and the start-sending key');
   saved := SaveRing;
   try
      CheckEquals('U30', KeyedBy(' '), 'space: one 30-tenth gap, no trailing gap');
      CheckEquals('U15', KeyedBy('^'), '^: one 15-tenth half space, no trailing gap');
      (* '@' has no arm, so it reaches only the trailing-gap rule. This was a
        nil write too, the same as the space. *)
      CheckEquals('U20', KeyedBy('@'), 'an unmapped printable character is a bare gap');
      CheckEquals('', KeyedBy(TEST_START_KEY), 'the start-sending-now key keys nothing');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_ControlCharacters;
var
   saved: TRingState;
begin
   (* Below ' ', so none of these gets the trailing gap. *)
   BeginTest('control characters: the long elements and the speed/weight commands');
   saved := SaveRing;
   try
      CheckEquals('K22 U10', KeyedBy(ControlE), 'Ctrl-E');
      CheckEquals('K26 U10', KeyedBy(ControlDash), 'Ctrl-dash');
      CheckEquals('K30 U10', KeyedBy(ControlK), 'Ctrl-K');
      CheckEquals('K34 U10', KeyedBy(ControlN), 'Ctrl-N');
      CheckEquals('K38 U10', KeyedBy(ControlO), 'Ctrl-O');
      CheckEquals('K6 U10', KeyedBy(ControlP), 'Ctrl-P');
      CheckEquals('K8 U10', KeyedBy(ControlQ), 'Ctrl-Q');
      CheckEquals('K10 U10', KeyedBy(ControlBackSlash), 'Ctrl-backslash');
      CheckEquals('K12 U10', KeyedBy(ControlV), 'Ctrl-V');
      CheckEquals('K14 U10', KeyedBy(ControlL), 'Ctrl-L');
      CheckEquals('K0', KeyedBy(ControlF), 'Ctrl-F: speed up, a zero-length keyed command');
      CheckEquals('U0', KeyedBy(ControlS), 'Ctrl-S: slow down, a zero-length unkeyed command');
      CheckEquals('U-1', KeyedBy(ControlX), 'Ctrl-X: decrease weight');
      CheckEquals('K-1', KeyedBy(ControlY), 'Ctrl-Y: increase weight');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_DahLengthFollowsTheSetting;
var
   saved: TRingState;
begin
   BeginTest('a dah is DitDahRatio x 10 tenths, read when it is written');
   saved := SaveRing;
   try
      Settings.Cw.DitDahRatio := 4;
      CheckEquals(ExpectedFromMorse('-.-', 40), KeyedBy('K'), 'ratio 4: K is 40 10 40');
      Settings.Cw.DitDahRatio := 6;
      CheckEquals(ExpectedFromMorse('-', 60), KeyedBy('T'), 'ratio 6: T is one 60');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_AddStringToCWBuffer;
var
   saved: TRingState;
   mark: integer;
begin
   BeginTest('AddStringToCWBuffer: characters, upper-casing, the tone and the Esc command escape');
   saved := SaveRing;
   try
      mark := CWBufferEnd;
      CPUKeyer.AddStringToCWBuffer('cq de', 650);
      CheckEquals(ExpectedFromMorse('-.-.', 30) + ' ' + ExpectedFromMorse('--.-', 30) +
                  ' U30 ' +
                  ExpectedFromMorse('-..', 30) + ' ' + ExpectedFromMorse('.', 30),
                  RingText(mark), 'cq de');
      CheckEquals(650, MonitorTone, 'the tone argument becomes the monitor tone');

      (* Esc then a digit is a command element whose length is '0' minus the
        digit; its Key is NOT written (whatever the slot held), so only the
        length is pinned. *)
      mark := CWBufferEnd;
      (* #27 is ControlLeftBracket, written as a literal so the Str160
        parameter takes a constant rather than a narrowed UnicodeString. *)
      CPUKeyer.AddStringToCWBuffer(#27'5E', 0);
      CheckEquals(-5, CPUKeyer.BufferedElement(mark).length, 'Esc 5 writes a length of -5');
      CheckEquals((mark + 4) mod CWBufferSize, CWBufferEnd, 'Esc 5 is one element, E is three');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_RingWrapsAtBufferSize;
var
   saved: TRingState;
   mark: integer;
   element: CWElementRecord;
begin
   (* The ring's modulus is CWBufferSize, ONE LESS than the array holds
     (0..CWBufferSize), so the last slot is never written by an append. *)
   BeginTest('the ring wraps modulo CWBufferSize');
   saved := SaveRing;
   try
      mark := CWBufferSize - 1;
      CWBufferEnd := mark;
      CWBufferStart := mark;
      CPUKeyer.AddCharacterToCWBuffer('E');
      CheckEquals(2, CWBufferEnd, 'E (3 elements) from CWBufferSize-1 ends at 2');
      CheckEquals('K10 U10 U20', RingText(mark), 'E read across the wrap');
      element := CPUKeyer.BufferedElement(0);
      CheckEquals(10, element.length, 'slot 0 holds the dit''s unkeyed half');
      CheckFalse(element.Key, 'slot 0 is unkeyed');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_DeleteLastCharacter;
var
   saved: TRingState;
   afterA: integer;
   afterB: integer;
begin
   BeginTest('DeleteLastCharacter retracts the last character back to the previous gap');
   saved := SaveRing;
   try
      CPUKeyer.AddCharacterToCWBuffer('A');
      afterA := CWBufferEnd;
      CPUKeyer.AddCharacterToCWBuffer('B');
      afterB := CWBufferEnd;
      CheckTrue(afterB <> afterA, 'B wrote something');
      CheckTrue(CPUKeyer.DeleteLastCharacter, 'B is retracted');
      CheckEquals(afterA, CWBufferEnd, 'the ring ends after A''s gap again');
      (* Today's behaviour, pinned rather than endorsed: the FIRST character in
        the ring has no gap before it, so it cannot be retracted. *)
      CheckFalse(CPUKeyer.DeleteLastCharacter, 'the only character left is not retracted');
      CheckEquals(afterA, CWBufferEnd, 'and the ring is unchanged');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_DeleteLastCharacterAtEndZero;
var
   saved: TRingState;
   retracted: boolean;
begin
   (* End = 0 is where the hand-written End - 1 went wrong (-1 never equals
     Start). FIXED in P6 (NY4I, 2026-10-17). *)
   BeginTest('DeleteLastCharacter at End = 0: retracts across the wrap, never walks the stale ring');
   saved := SaveRing;
   try
      (* A STALE character well behind the live ring: its trailing gap is a
        20-tenth unkeyed slot at 12, exactly what the walk looks for. *)
      CWBufferEnd := 10;
      CWBufferStart := 10;
      CPUKeyer.AddCharacterToCWBuffer('E');
      CheckEquals(13, CWBufferEnd, 'the stale E fills 10..12, its gap at 12');

      (* One element left to send, at CWBufferSize - 1, and End = 0. There is
        no earlier gap in the LIVE ring, so nothing may be retracted. The old
        walk went round from CWBufferSize - 2 downwards and cut the ring at
        the first stale gap it met -- 12 at the latest. *)
      CWBufferStart := CWBufferSize - 1;
      CWBufferEnd := 0;
      retracted := CPUKeyer.DeleteLastCharacter;
      CheckFalse(retracted, 'nothing in the live ring to retract');
      CheckEquals(0, CWBufferEnd, 'End is untouched -- the stale gap at 12 was never reached');

      (* And a real retraction across the wrap: E E <space> written from
        CWBufferSize - 7 ends exactly at 0, so the space is the last
        "character" and the second E's gap, at CWBufferSize - 2, is where the
        ring is cut. Same answer the old code gave. *)
      CWBufferEnd := CWBufferSize - 7;
      CWBufferStart := CWBufferEnd;
      CPUKeyer.AddCharacterToCWBuffer('E');
      CPUKeyer.AddCharacterToCWBuffer('E');
      CPUKeyer.AddCharacterToCWBuffer(' ');
      CheckEquals(0, CWBufferEnd, 'E E <space> from CWBufferSize - 7 ends at 0');
      retracted := CPUKeyer.DeleteLastCharacter;
      CheckTrue(retracted, 'the space after the second E is retracted');
      CheckEquals(CWBufferSize - 1, CWBufferEnd, 'the ring now ends just after the second E''s gap');
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.Test_RingSlotArithmetic;
var
   i: integer;
   allInverse: boolean;
begin
   BeginTest('NextRingSlot / PreviousRingSlot step modulo CWBufferSize');
   CheckEquals(CWBufferSize - 1, PreviousRingSlot(0), 'the slot before 0 is CWBufferSize - 1');
   CheckEquals(4, PreviousRingSlot(5), 'the slot before 5 is 4');
   CheckEquals(CWBufferSize - 2, PreviousRingSlot(CWBufferSize - 1), 'the slot before the last');
   CheckEquals(0, NextRingSlot(CWBufferSize - 1), 'the slot after the last is 0');
   CheckEquals(5, NextRingSlot(4), 'the slot after 4 is 5');
   allInverse := True;
   for i := 0 to CWBufferSize - 1 do
      begin
      if (NextRingSlot(PreviousRingSlot(i)) <> i) or
         (PreviousRingSlot(NextRingSlot(i)) <> i) or
         (PreviousRingSlot(i) > CWBufferSize - 1) then
         begin
         allInverse := False;
         end;
      end;
   CheckTrue(allInverse, 'the two steps are inverses on every slot, and never reach CWBufferSize');
end;

procedure TCPUKeyerRingTests.Test_FlushedStartStopsInOneStep;
const
   ENDS: array[0..4] of integer = (0, 1, 5, CWBufferSize - 2, CWBufferSize - 1);
var
   i: integer;
   ringEnd: integer;
   slot: integer;
   steps: integer;
begin
   (* What FlushCWBuffer does with the CW thread running -- Start one slot
     behind End -- and then CWThreadProc's own stepping (NextRingSlot while
     Start <> End). It must take exactly ONE step to reach End and stop.
     The old wrap put Start at CWBufferSize for End = 0, from which the loop
     stepped to 1 and walked 2,046 stale slots (NY4I's ruling: fixed in P6). *)
   BeginTest('a flushed Start reaches End in exactly one send-loop step, End = 0 included');
   for i := Low(ENDS) to High(ENDS) do
      begin
      ringEnd := ENDS[i];
      slot := PreviousRingSlot(ringEnd);
      steps := 0;
      while (slot <> ringEnd) and (steps <= CWBufferSize) do
         begin
         slot := NextRingSlot(slot);
         Inc(steps);
         end;
      CheckEquals(1, steps, SysUtils.Format('End = %d: steps to stop', [ringEnd]));
      end;
end;

procedure TCPUKeyerRingTests.Test_RingIsOwnedByTheKeyer;
begin
   (* The structural half of the D4 fix: the ring is IN the keyer, so there is
     no pointer to be nil and no block to leak. SizeOf(TYPE), never of the
     instance. *)
   BeginTest('the element ring is a field of K1EAKeyer, not a heap block');
   CheckTrue(SizeOf(K1EAKeyer) >= (CWBufferSize + 1) * SizeOf(CWElementRecord),
             SysUtils.Format('SizeOf(K1EAKeyer) = %d holds %d elements of %d bytes',
                    [SizeOf(K1EAKeyer), CWBufferSize + 1, SizeOf(CWElementRecord)]));
end;

procedure TCPUKeyerRingTests.Test_FeedingTheRingAllocatesNothing;
var
   saved: TRingState;
   before: PtrUInt;
   after: PtrUInt;
begin
   (* The leak half. The old ring was a 16 KB New() on the first Dit that was
     never disposed; now nothing on this path touches the heap. The logger is
     exercised once first so its own first-use setup is not counted. *)
   BeginTest('filling the ring allocates nothing on the heap');
   saved := SaveRing;
   try
      logger.Debug('[uTestCPUKeyerRing] warm-up %s', ['x']);
      before := GetFPCHeapStatus.CurrHeapUsed;
      CPUKeyer.AddCharacterToCWBuffer(' ');
      CPUKeyer.AddStringToCWBuffer('CQ TEST 5NN', 0);
      after := GetFPCHeapStatus.CurrHeapUsed;
      CheckTrue(after = before,
                SysUtils.Format('heap in use %d before, %d after', [before, after]));
   finally
      RestoreRing(saved);
   end;
end;

procedure TCPUKeyerRingTests.RunAllTests;
begin
   (* FIRST, deliberately -- see the unit header. *)
   Test_SpaceFirstWritesAGap;
   Test_LettersAndDigitsAreInternationalMorse;
   Test_PunctuationAndProsigns;
   Test_LowerCaseIsUpperCase;
   Test_SpacingAndUnkeyedCharacters;
   Test_ControlCharacters;
   Test_DahLengthFollowsTheSetting;
   Test_AddStringToCWBuffer;
   Test_RingWrapsAtBufferSize;
   Test_DeleteLastCharacter;
   Test_DeleteLastCharacterAtEndZero;
   Test_RingSlotArithmetic;
   Test_FlushedStartStopsInOneStep;
   Test_RingIsOwnedByTheKeyer;
   Test_FeedingTheRingAllocatesNothing;
end;

end.

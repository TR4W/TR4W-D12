unit uTestRadioStatus;
{$I ..\..\src\tr4w.inc}

{
  Pins LogRadio.RadioStatusDiffers -- the change detector that drives the radio
  display and the UDP stream.

  WHY EXHAUSTIVELY, FIELD BY FIELD.  The routine it replaced was a byte scan
  over the whole record, so it noticed every field automatically, including
  fields nobody remembered.  A field-wise comparison is only as complete as the
  person who wrote it, and a field left out does not fail loudly: change
  detection simply goes blind to it, the display stops following that value,
  and nothing in the code says why.

  So every field is asserted in BOTH directions -- change it and the records
  must differ, restore it and they must not.  Adding a field to
  RadioStatusRecord without adding it to RadioStatusDiffers would leave this
  file still passing, which is why there is also a SIZE GUARD: it fails when
  the record grows, and says what to do about it.
}

interface

uses
   SysUtils, uTR4WTestFramework, VC, LogRadio;

type
   TRadioStatusTests = class(TTestCase)
   protected
      procedure Test_IdenticalRecordsDoNotDiffer;
      procedure Test_ARecordDoesNotDifferFromItself;
      procedure Test_ZeroedRecordsDoNotDiffer;
      procedure Test_TopLevelFieldsAreEachDetected;
      procedure Test_EveryVFOSlotAndFieldIsDetected;
      procedure Test_RecordSizeIsPinned;
      procedure Test_PaddingExistsAndIsNotState;
      procedure Test_PublishTogglesVersionOddThenEven;
      procedure Test_SnapshotReturnsThePublishedRecord;
      procedure Test_SnapshotStillReturnsACopyIfTheVersionIsLeftOdd;
      procedure Test_CurrentAndFilteredAreReadSeparately;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   // Derived, not guessed: VFOStatusType declares two longints and six
   // one-byte enums (14 bytes) and aligns to 16.  RadioStatusRecord is the two
   // 4-slot VFO arrays (2 x 4 x 16 = 128), six 4-byte scalars -- Split/RIT/XIT
   // are longbool, not byte -- (24), and six one-byte enums padded to 8: 160.
   // Test_RecordSizeIsPinned is what proves the arithmetic.
   EXPECTED_VFO_SIZE    = 16;
   EXPECTED_STATUS_SIZE = 160;

// A non-zero baseline.  Testing from an all-zero record would let a comparison
// that accidentally asked `<> 0` instead of `a <> b` pass everything.
function Baseline: RadioStatusRecord;
var
   v: ActiveVFOStatusType;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Freq          := 14025000;
   Result.Split         := True;
   Result.RIT           := True;
   Result.XIT           := False;
   Result.RITFreq       := -250;
   Result.PrevRITFreq   := -100;
   Result.Band          := Band20;
   Result.Mode          := CW;
   Result.ExtendedMode  := eCW;
   Result.VFOStatus     := VFOA;
   Result.PrevVFOStatus := VFOB;
   Result.TXOn          := False;
   for v := Low(ActiveVFOStatusType) to High(ActiveVFOStatusType) do
      begin
      Result.VFO[v].Frequency    := 14025000 + Ord(v);
      Result.VFO[v].RITFreq      := -250 - Ord(v);
      Result.VFO[v].Band         := Band20;
      Result.VFO[v].Mode         := CW;
      Result.VFO[v].Split        := True;
      Result.VFO[v].RIT          := True;
      Result.VFO[v].XIT          := False;
      Result.VFO[v].ExtendedMode := eCW;

      Result.previousVFO[v].Frequency    := 7025000 + Ord(v);
      Result.previousVFO[v].RITFreq      := 100 + Ord(v);
      Result.previousVFO[v].Band         := Band40;
      Result.previousVFO[v].Mode         := Phone;
      Result.previousVFO[v].Split        := False;
      Result.previousVFO[v].RIT          := False;
      Result.previousVFO[v].XIT          := True;
      Result.previousVFO[v].ExtendedMode := eSSB;
      end;
end;

procedure TRadioStatusTests.Test_IdenticalRecordsDoNotDiffer;
var
   a, b: RadioStatusRecord;
begin
   BeginTest('Test_IdenticalRecordsDoNotDiffer');
   a := Baseline;
   b := Baseline;
   CheckFalse(RadioStatusDiffers(a, b), 'two identical baselines must not differ');
end;

procedure TRadioStatusTests.Test_ARecordDoesNotDifferFromItself;
var
   a: RadioStatusRecord;
begin
   BeginTest('Test_ARecordDoesNotDifferFromItself');
   a := Baseline;
   CheckFalse(RadioStatusDiffers(a, a), 'a record must not differ from itself');
end;

procedure TRadioStatusTests.Test_ZeroedRecordsDoNotDiffer;
var
   a, b: RadioStatusRecord;
begin
   BeginTest('Test_ZeroedRecordsDoNotDiffer');
   FillChar(a, SizeOf(a), 0);
   FillChar(b, SizeOf(b), 0);
   CheckFalse(RadioStatusDiffers(a, b), 'two zeroed records must not differ');
end;

procedure TRadioStatusTests.Test_TopLevelFieldsAreEachDetected;
var
   a, b: RadioStatusRecord;

   // Assert the mutation is seen, then put the record back and assert equality
   // again.  The restore half is what catches a comparison that returns True
   // unconditionally -- which would pass every "is it detected" assertion.
   procedure Restored(const aWhat: string);
   begin
      CheckTrue(RadioStatusDiffers(a, b), aWhat + ' must be detected as a change');
      b := Baseline;
      CheckFalse(RadioStatusDiffers(a, b), aWhat + ' restored must compare equal');
   end;

begin
   BeginTest('Test_TopLevelFieldsAreEachDetected');
   a := Baseline;
   b := Baseline;

   b.Freq := a.Freq + 1;                Restored('Freq (1 Hz)');
   b.Split := not a.Split;              Restored('Split');
   b.RIT := not a.RIT;                  Restored('RIT');
   b.XIT := not a.XIT;                  Restored('XIT');
   b.RITFreq := a.RITFreq + 1;          Restored('RITFreq');
   b.PrevRITFreq := a.PrevRITFreq + 1;  Restored('PrevRITFreq');
   b.Band := Band40;                    Restored('Band');
   b.Mode := Phone;                     Restored('Mode');
   b.ExtendedMode := eSSB;              Restored('ExtendedMode');
   b.VFOStatus := VFOB;                 Restored('VFOStatus');
   b.PrevVFOStatus := VFOA;             Restored('PrevVFOStatus');
   b.TXOn := not a.TXOn;                Restored('TXOn');
end;

// vfoUnknown and vfoMem are included deliberately.  pFactoryRadio only fills
// VFOA and VFOB today, but the byte scan this replaced covered all four slots,
// and narrowing what counts as a change while claiming to preserve behaviour is
// exactly the silent difference this exercise exists to avoid.
procedure TRadioStatusTests.Test_EveryVFOSlotAndFieldIsDetected;
var
   a, b: RadioStatusRecord;
   v: ActiveVFOStatusType;
   slot: string;

   procedure Restored(const aWhat: string);
   begin
      CheckTrue(RadioStatusDiffers(a, b), aWhat + ' must be detected as a change');
      b := Baseline;
      CheckFalse(RadioStatusDiffers(a, b), aWhat + ' restored must compare equal');
   end;

begin
   BeginTest('Test_EveryVFOSlotAndFieldIsDetected');
   a := Baseline;
   b := Baseline;

   for v := Low(ActiveVFOStatusType) to High(ActiveVFOStatusType) do
      begin
      slot := 'VFO[' + IntToStr(Ord(v)) + '].';

      b.VFO[v].Frequency := a.VFO[v].Frequency + 1;  Restored(slot + 'Frequency');
      b.VFO[v].RITFreq := a.VFO[v].RITFreq + 1;      Restored(slot + 'RITFreq');
      b.VFO[v].Band := Band80;                       Restored(slot + 'Band');
      b.VFO[v].Mode := Digital;                      Restored(slot + 'Mode');
      b.VFO[v].Split := not a.VFO[v].Split;          Restored(slot + 'Split');
      b.VFO[v].RIT := not a.VFO[v].RIT;              Restored(slot + 'RIT');
      b.VFO[v].XIT := not a.VFO[v].XIT;              Restored(slot + 'XIT');
      b.VFO[v].ExtendedMode := eFT8;                 Restored(slot + 'ExtendedMode');

      slot := 'previousVFO[' + IntToStr(Ord(v)) + '].';

      b.previousVFO[v].Frequency := a.previousVFO[v].Frequency + 1;
      Restored(slot + 'Frequency');
      b.previousVFO[v].RITFreq := a.previousVFO[v].RITFreq + 1;
      Restored(slot + 'RITFreq');
      b.previousVFO[v].Band := Band80;               Restored(slot + 'Band');
      b.previousVFO[v].Mode := Digital;              Restored(slot + 'Mode');
      b.previousVFO[v].Split := not a.previousVFO[v].Split;
      Restored(slot + 'Split');
      b.previousVFO[v].RIT := not a.previousVFO[v].RIT;
      Restored(slot + 'RIT');
      b.previousVFO[v].XIT := not a.previousVFO[v].XIT;
      Restored(slot + 'XIT');
      b.previousVFO[v].ExtendedMode := eFT8;         Restored(slot + 'ExtendedMode');
      end;
end;

// The guard that keeps the tests above honest.  SizeOf is the only thing the
// compiler will tell us about a record's shape at test time; it moves when a
// field is added, widened, or reordered across an alignment boundary.
procedure TRadioStatusTests.Test_RecordSizeIsPinned;
begin
   BeginTest('Test_RecordSizeIsPinned');

   CheckEquals(EXPECTED_VFO_SIZE, SizeOf(VFOStatusType),
      'VFOStatusType changed size.  Add the new or changed field to '
      + 'LogRadio.VFOStatusDiffers AND to Test_EveryVFOSlotAndFieldIsDetected, '
      + 'then update EXPECTED_VFO_SIZE here.  Skip the first and change '
      + 'detection goes blind to that field: the radio display silently stops '
      + 'following it.');

   CheckEquals(EXPECTED_STATUS_SIZE, SizeOf(RadioStatusRecord),
      'RadioStatusRecord changed size.  Add the new or changed field to '
      + 'LogRadio.RadioStatusDiffers AND to Test_TopLevelFieldsAreEachDetected, '
      + 'then update EXPECTED_STATUS_SIZE here.  Skip the first and change '
      + 'detection goes blind to that field: the radio display silently stops '
      + 'following it.');
end;

// The padding this change is about, made visible rather than asserted away.
// VFOStatusType declares 4+4+1+1+1+1+1+1 = 14 bytes and occupies more, so the
// remainder belongs to no field -- across eight slots in the two arrays.  A
// byte comparison was reading those bytes as though they were radio state.
procedure TRadioStatusTests.Test_PaddingExistsAndIsNotState;
const
   DECLARED_VFO_BYTES = 4 + 4 + 1 + 1 + 1 + 1 + 1 + 1;
begin
   BeginTest('Test_PaddingExistsAndIsNotState');
   CheckTrue(SizeOf(VFOStatusType) > DECLARED_VFO_BYTES,
      'VFOStatusType was expected to carry alignment padding.  If it no longer '
      + 'does, the note on LogRadio.RadioStatusDiffers explaining why a byte '
      + 'comparison was wrong should be revisited rather than left claiming '
      + 'something untrue.');
end;

// ---------------------------------------------------------------------------
// The seqlock.
//
// These are single-threaded on purpose.  A unit test cannot reliably provoke a
// real reader/writer collision -- the window is nanoseconds and the outcome is
// timing-dependent, so a test that tried would be flaky and would prove nothing
// on the run where it happened not to collide.  What IS worth pinning is the
// protocol the collision detection rests on: odd while writing, even when
// coherent, and a reader that cannot get a stable version still returns
// something rather than spinning forever.
// ---------------------------------------------------------------------------

// A standalone RadioObject, so the tests never touch the real Radio1/Radio2 the
// rest of the program is using.
procedure ResetRig(var rig: RadioObject);
begin
   FillChar(rig, SizeOf(rig), 0);
end;

procedure TRadioStatusTests.Test_PublishTogglesVersionOddThenEven;
var
   rig: RadioObject;
begin
   BeginTest('Test_PublishTogglesVersionOddThenEven');
   ResetRig(rig);

   CheckEquals(0, integer(rig.StatusVersion and 1),
      'a fresh rig must start on an EVEN version, or its very first snapshot '
      + 'would be treated as mid-write');

   BeginStatusPublish(@rig);
   CheckEquals(1, integer(rig.StatusVersion and 1),
      'BeginStatusPublish must make the version odd -- odd is what tells a '
      + 'reader a write is in progress');

   EndStatusPublish(@rig);
   CheckEquals(0, integer(rig.StatusVersion and 1),
      'EndStatusPublish must make the version even again');

   // The version must MOVE, not just toggle parity: a reader that copied across
   // a complete publish sees before <> after and retries.  A counter that
   // returned to its old value would let that reader accept a torn copy.
   BeginStatusPublish(@rig);
   EndStatusPublish(@rig);
   CheckEquals(4, integer(rig.StatusVersion),
      'two complete publishes must advance the version by four, so a reader '
      + 'spanning either of them detects it');
end;

procedure TRadioStatusTests.Test_SnapshotReturnsThePublishedRecord;
var
   rig: RadioObject;
   snap: RadioStatusRecord;
begin
   BeginTest('Test_SnapshotReturnsThePublishedRecord');
   ResetRig(rig);

   BeginStatusPublish(@rig);
   rig.FilteredStatus := Baseline;
   EndStatusPublish(@rig);

   snap := ReadRadioStatus(@rig);
   CheckFalse(RadioStatusDiffers(snap, rig.FilteredStatus),
      'a snapshot taken on an even version must equal the published record');
   CheckEquals(14025000, snap.Freq, 'snapshot carried the wrong frequency');
end;

// The bounded-retry path.  If a publish were ever left unbalanced -- an
// exception escaping between Begin and End -- the version would stay odd and a
// naive `repeat until stable` would hang the UI thread.  It must degrade to
// "returns a copy", which is exactly what every unconverted caller already
// does by reading the field directly.
procedure TRadioStatusTests.Test_SnapshotStillReturnsACopyIfTheVersionIsLeftOdd;
var
   rig: RadioObject;
   snap: RadioStatusRecord;
begin
   BeginTest('Test_SnapshotStillReturnsACopyIfTheVersionIsLeftOdd');
   ResetRig(rig);

   rig.FilteredStatus := Baseline;
   BeginStatusPublish(@rig);   // deliberately never ended: version stays ODD

   snap := ReadRadioStatus(@rig);   // must return, not spin
   CheckEquals(14025000, snap.Freq,
      'a reader that cannot get a stable version must still hand back the last '
      + 'copy it took -- spinning forever here would hang the UI thread');
end;

procedure TRadioStatusTests.Test_CurrentAndFilteredAreReadSeparately;
var
   rig: RadioObject;
   cur, filt: RadioStatusRecord;
begin
   BeginTest('Test_CurrentAndFilteredAreReadSeparately');
   ResetRig(rig);

   BeginStatusPublish(@rig);
   rig.CurrentStatus := Baseline;
   rig.FilteredStatus := Baseline;
   rig.FilteredStatus.Freq := 7025000;   // filtered lags by a cycle
   EndStatusPublish(@rig);

   cur  := ReadRadioCurrentStatus(@rig);
   filt := ReadRadioStatus(@rig);

   CheckEquals(14025000, cur.Freq, 'ReadRadioCurrentStatus must read CurrentStatus');
   CheckEquals(7025000, filt.Freq, 'ReadRadioStatus must read FilteredStatus');
   CheckTrue(RadioStatusDiffers(cur, filt),
      'the two accessors must not be reading the same record');
end;

procedure TRadioStatusTests.RunAllTests;
begin
   Test_IdenticalRecordsDoNotDiffer;
   Test_ARecordDoesNotDifferFromItself;
   Test_ZeroedRecordsDoNotDiffer;
   Test_TopLevelFieldsAreEachDetected;
   Test_EveryVFOSlotAndFieldIsDetected;
   Test_RecordSizeIsPinned;
   Test_PaddingExistsAndIsNotState;
   Test_PublishTogglesVersionOddThenEven;
   Test_SnapshotReturnsThePublishedRecord;
   Test_SnapshotStillReturnsACopyIfTheVersionIsLeftOdd;
   Test_CurrentAndFilteredAreReadSeparately;
end;

end.

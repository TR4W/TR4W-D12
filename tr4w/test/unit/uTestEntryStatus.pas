unit uTestEntryStatus;

(* THE ENTRY AREA'S LOG STATUS -- uEntryStatus's rules (UI refresh proposal,
  "Save and status feedback", 2026-11-22).

  - A refusal wins over read-only; read-only shows between entries; nothing
    shows otherwise, so the panel can never stand for "saved".
  - A refusal outlives everything but a discard: it stays while either field
    holds anything but blanks (the exchange's single space is a keying state,
    not text).
  - The text is the headline, then the store's reason on its own line. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TEntryStatusTests = class(TTestCase)
   protected
      procedure Test_ARefusalWinsOverReadOnly;
      procedure Test_ReadOnlyShowsBetweenEntries;
      procedure Test_NothingShowsWhenTheLogIsWell;
      procedure Test_ARefusalStaysUntilTheEntryIsDiscarded;
      procedure Test_ARefusalNeverStartsFromTheFields;
      procedure Test_TheTextIsTheHeadlineThenTheReason;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uAppStrings,
   uEntryStatus;

procedure TEntryStatusTests.Test_ARefusalWinsOverReadOnly;
begin
   BeginTest('Test_ARefusalWinsOverReadOnly');
   CheckTrue(EntryStatusKind(True, True) = eskRefused, 'refused on a read-only log');
   CheckTrue(EntryStatusKind(True, False) = eskRefused, 'refused on a writable log');
end;

procedure TEntryStatusTests.Test_ReadOnlyShowsBetweenEntries;
begin
   BeginTest('Test_ReadOnlyShowsBetweenEntries');
   CheckTrue(EntryStatusKind(False, True) = eskReadOnly, 'read-only, no refusal showing');
end;

procedure TEntryStatusTests.Test_NothingShowsWhenTheLogIsWell;
begin
   BeginTest('Test_NothingShowsWhenTheLogIsWell');
   CheckTrue(EntryStatusKind(False, False) = eskNone, 'writable, no refusal');
   CheckEquals('', EntryStatusText(eskNone, 'a reason'), 'no text for none, whatever the reason');
   CheckEquals('', EntryStatusHeadline(eskNone), 'no headline for none');
end;

procedure TEntryStatusTests.Test_ARefusalStaysUntilTheEntryIsDiscarded;
begin
   BeginTest('Test_ARefusalStaysUntilTheEntryIsDiscarded');
   CheckTrue(RefusalStillShown(True, 'K1ABC', '599 CT'), 'both fields still typed');
   CheckTrue(RefusalStillShown(True, '', '599 CT'), 'the call cleared, the exchange kept');
   CheckTrue(RefusalStillShown(True, 'K1ABC', ''), 'the exchange cleared, the call kept');
   CheckFalse(RefusalStillShown(True, '', ''), 'both fields cleared: discarded');
   CheckFalse(RefusalStillShown(True, '', ' '),
              'the exchange''s single space is a keying state, not an entry');
   CheckFalse(RefusalStillShown(True, '  ', '   '), 'blanks only: discarded');
end;

procedure TEntryStatusTests.Test_ARefusalNeverStartsFromTheFields;
begin
   BeginTest('Test_ARefusalNeverStartsFromTheFields');
   CheckFalse(RefusalStillShown(False, 'K1ABC', '599 CT'),
              'typing does not show a refusal; only a refused save does');
end;

procedure TEntryStatusTests.Test_TheTextIsTheHeadlineThenTheReason;
begin
   BeginTest('Test_TheTextIsTheHeadlineThenTheReason');
   CheckEquals(string(SEntryStatusQsoNotSaved), EntryStatusHeadline(eskRefused), 'refused headline');
   CheckEquals(string(SEntryStatusLogReadOnly), EntryStatusHeadline(eskReadOnly), 'read-only headline');
   CheckEquals(string(SEntryStatusQsoNotSaved) + LineEnding + 'Log is read-only (disk full).',
               EntryStatusText(eskRefused, ' Log is read-only (disk full). '),
               'the reason on its own line, trimmed');
   CheckEquals(string(SEntryStatusLogReadOnly), EntryStatusText(eskReadOnly, '   '),
               'no reason: the headline alone');
end;

procedure TEntryStatusTests.RunAllTests;
begin
   Test_ARefusalWinsOverReadOnly;
   Test_ReadOnlyShowsBetweenEntries;
   Test_NothingShowsWhenTheLogIsWell;
   Test_ARefusalStaysUntilTheEntryIsDiscarded;
   Test_ARefusalNeverStartsFromTheFields;
   Test_TheTextIsTheHeadlineThenTheReason;
end;

end.

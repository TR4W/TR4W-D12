unit uTestLogNote;

(* THE NOTE LAYOUT -- uLogNote.

  A note's text lives in a region that starts at Prefix and runs on across the
  fields after it. .TRW files and multi-op peers carry notes in exactly that
  layout, so the helper that now owns it has to reproduce the bytes the program
  always wrote, not merely something that reads back. That is the test that
  matters most here: TestMatchesTheBytesTheProgramWrote builds one record the
  old way and one through SetNoteText and compares them whole.

  The rest pin the edges a note actually has: the longest one the writer
  allows, one past it, a short note over a long one, and an empty one. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogNoteTests = class(TTestCase)
   protected
      procedure TestTheRegionFitsInTheRecord;
      procedure TestTextRoundTrips;
      procedure TestMatchesTheBytesTheProgramWrote;
      procedure TestLongestNoteIsKeptWhole;
      procedure TestLongerNoteIsTruncated;
      procedure TestShorterNoteLeavesNoTail;
      procedure TestEmptyNote;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, VC, uLogNote;

(* THE ONLY ARITHMETIC ON ADDRESSES ANYWHERE NEAR THIS LAYOUT, AND IT IS IN A
  TEST. It is what proves the Move and FillChar in uLogNote cannot leave the
  record: if ContestExchange ever shrinks behind Prefix, this fails before a
  note is written past the end of one. *)
procedure TLogNoteTests.TestTheRegionFitsInTheRecord;
var
   ce     : ContestExchange;
   offset : integer;
begin
   BeginTest('the note region lies wholly inside ContestExchange');
   offset := integer(PtrUInt(@ce.Prefix) - PtrUInt(@ce));
   Check(offset + NOTE_MAX_LENGTH <= SizeOf(ContestExchange),
         Format('Prefix is at byte %d of a %d-byte record, leaving %d for a note',
                [offset, integer(SizeOf(ContestExchange)),
                 integer(SizeOf(ContestExchange)) - offset]));
end;

procedure TLogNoteTests.TestTextRoundTrips;
var
   ce : ContestExchange;
begin
   BeginTest('a note that is set is the note that is read');
   FillChar(ce, SizeOf(ce), 0);
   ce.ceRecordKind := rkNote;
   SetNoteText(ce, 'the rig drifted 200 Hz after the band change');
   CheckEquals('the rig drifted 200 Hz after the band change',
               string(NoteText(ce)), 'the text comes back whole');
end;

(* THE COMPATIBILITY TEST. The record built the way tr4w_add_note_in_log built
  it, before this unit existed, against the one SetNoteText builds. They must
  match to the byte: that record is what a .TRW holds and what a multi-op peer
  receives. CompareMem is right here and nowhere else -- the question IS the
  memory layout. *)
procedure TLogNoteTests.TestMatchesTheBytesTheProgramWrote;
var
   original  : ContestExchange;
   viaHelper : ContestExchange;
   s         : ShortString;
begin
   BeginTest('SetNoteText writes exactly the bytes the note writer always wrote');
   s := 'QSY to 14.025 for the pileup';

   FillChar(original, SizeOf(original), 0);
   original.ceRecordKind := rkNote;
   Move(s[1], original.Prefix, Length(s));

   FillChar(viaHelper, SizeOf(viaHelper), 0);
   viaHelper.ceRecordKind := rkNote;
   SetNoteText(viaHelper, s);

   CheckTrue(CompareMem(@original, @viaHelper, SizeOf(ContestExchange)),
             'the two records are identical, byte for byte');
end;

procedure TLogNoteTests.TestLongestNoteIsKeptWhole;
var
   ce   : ContestExchange;
   text : AnsiString;
begin
   BeginTest('a note of exactly NOTE_MAX_LENGTH comes back whole');
   text := AnsiString(StringOfChar('x', NOTE_MAX_LENGTH));
   FillChar(ce, SizeOf(ce), 0);
   SetNoteText(ce, text);
   CheckEquals(NOTE_MAX_LENGTH, Length(NoteText(ce)),
               'all of it, with no terminator inside the region to stop at');
   CheckEquals(string(text), string(NoteText(ce)), 'and it is the same text');
end;

procedure TLogNoteTests.TestLongerNoteIsTruncated;
var
   ce   : ContestExchange;
   text : AnsiString;
begin
   BeginTest('a note longer than NOTE_MAX_LENGTH keeps its first NOTE_MAX_LENGTH');
   text := AnsiString(StringOfChar('a', NOTE_MAX_LENGTH) + StringOfChar('b', 20));
   FillChar(ce, SizeOf(ce), 0);
   SetNoteText(ce, text);
   CheckEquals(string(Copy(text, 1, NOTE_MAX_LENGTH)), string(NoteText(ce)),
               'truncated at the region, as the writer always truncated');
end;

procedure TLogNoteTests.TestShorterNoteLeavesNoTail;
var
   ce : ContestExchange;
begin
   BeginTest('a short note written over a long one leaves none of the long one');
   FillChar(ce, SizeOf(ce), 0);
   SetNoteText(ce, AnsiString(StringOfChar('z', 60)));
   SetNoteText(ce, 'short');
   CheckEquals('short', string(NoteText(ce)),
               'the region was cleared, not just overwritten at the front');
end;

procedure TLogNoteTests.TestEmptyNote;
var
   ce : ContestExchange;
begin
   BeginTest('an empty note reads back empty');
   FillChar(ce, SizeOf(ce), 0);
   SetNoteText(ce, AnsiString(StringOfChar('q', 30)));
   SetNoteText(ce, '');
   CheckEquals('', string(NoteText(ce)), 'nothing left in the region');
end;

procedure TLogNoteTests.RunAllTests;
begin
   TestTheRegionFitsInTheRecord;
   TestTextRoundTrips;
   TestMatchesTheBytesTheProgramWrote;
   TestLongestNoteIsKeptWhole;
   TestLongerNoteIsTruncated;
   TestShorterNoteLeavesNoTail;
   TestEmptyNote;
end;

end.

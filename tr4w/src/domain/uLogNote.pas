unit uLogNote;

(* WHERE A NOTE'S TEXT LIVES IN A LOG RECORD -- THE ONE PLACE THAT KNOWS.

  A note is not a field. tr4w_add_note_in_log zero-fills a ContestExchange,
  marks it rkNote, and puts the text in STARTING AT Prefix -- so up to
  NOTE_MAX_LENGTH bytes run on across Prefix, the pad byte after it, Callsign
  and the fields after that, terminated by the zero fill.

  THAT LAYOUT IS AN ENCODING WITH DEPLOYED READERS, which is why it is kept
  rather than replaced. Every D7-written .TRW carries notes this way, so the
  importer must still read it there. The multi-op wire does NOT carry the
  record any more (protocol 5, 2026-11: a QSO or note travels as named wire
  columns, the text in `notes` -- uQsoColumns, uWireQso), so the overlay's
  readers are the .TRW import and this program's own in-memory record.
  Moving a note elsewhere in the record waits on issue 386's batch B, which
  gives the importer a frozen copy of the D7 record.

  WHAT WAS WRONG WAS EVERYONE REACHING INTO IT BY HAND. A writer and three
  readers each spelled the layout themselves. Two of the readers read Prefix
  as a ShortString, which takes the note's first character as a length. And
  the SQLite mapper stored Prefix and Callsign as separate typed columns, so a
  note came back from the log as two truncated fragments, each missing its
  first letter. uTestLogRepository.TestANoteSurvivesTheLog measured it:

      wrote      'the rig drifted 200 Hz after the band change'
      read back  Prefix 'he rig', Callsign 'rifted 200 Hz'

  So the layout is spelled HERE, once, under test, and the log stores the text
  in its own `notes` column. *)

{$I ..\tr4w.inc}

interface

uses
   VC;

const
   (* The longest note tr4w_add_note_in_log writes, and so the width of the
     region a note occupies. *)
   NOTE_MAX_LENGTH = 80;

(* The note's text: the region's bytes up to the first NUL, or all
  NOTE_MAX_LENGTH of them. Bytes, not decoded text -- a note is whatever the
  operator's code page produced, and the .TRW and the wire carry it as such. *)
function NoteText(const aQso: ContestExchange): AnsiString;

(* Writes a note's text into the region, clearing the WHOLE region first so a
  shorter note written over a longer one leaves no tail -- the same bytes the
  zero fill gives a brand-new note. Text past NOTE_MAX_LENGTH is dropped, as
  the writer always dropped it. *)
procedure SetNoteText(var aQso: ContestExchange; const aText: AnsiString);

(* WHERE A NOTE WAS WRITTEN, FOR THE NOTE REPORT (issue 21): band, mode, the
  frequency in kHz to 100 Hz and the operator -- "20 CW 14025.0 NY4I". All
  four fields lie OUTSIDE the text region, so SetNoteText never touches them;
  a frequency of 0 (no radio) and an empty operator are left out. *)
function NoteContextText(const aQso: ContestExchange): AnsiString;

implementation

uses
   SysUtils,     (* IntToStr, Trim *)
   utils_text;   (* CharBufferBytes -- the operator's NUL-padded buffer *)

function NoteText(const aQso: ContestExchange): AnsiString;
var
   region : array[0..NOTE_MAX_LENGTH - 1] of AnsiChar;
   n      : integer;
   i      : integer;
begin
   (* A COPY OF THE BYTES, NOT A POINTER WALK. The Move is wider than Prefix on
     purpose -- the region IS wider than the field, that is the layout -- and
     this unit is the only place in the program allowed to say so.
     uTestLogNote proves the region lies wholly inside the record. *)
   Move(aQso.Prefix, region, SizeOf(region));

   n := 0;
   while (n < SizeOf(region)) and (region[n] <> #0) do
      begin
      Inc(n);
      end;

   SetLength(Result, n);
   for i := 1 to n do
      begin
      Result[i] := region[i - 1];
      end;
end;

procedure SetNoteText(var aQso: ContestExchange; const aText: AnsiString);
var
   n : integer;
begin
   FillChar(aQso.Prefix, NOTE_MAX_LENGTH, 0);

   n := Length(aText);
   if n > NOTE_MAX_LENGTH then
      begin
      n := NOTE_MAX_LENGTH;
      end;

   if n > 0 then
      begin
      Move(aText[1], aQso.Prefix, n);
      end;
end;

function NoteContextText(const aQso: ContestExchange): AnsiString;
var
   op : AnsiString;
begin
   Result := AnsiString(BandStringsArrayWithOutSpaces[aQso.Band]) + ' ' +
             AnsiString(ModeStringArray[aQso.Mode]);

   if aQso.Frequency > 0 then
      begin
      Result := Result + ' ' +
                AnsiString(IntToStr(aQso.Frequency div 1000)) + '.' +
                AnsiString(IntToStr((aQso.Frequency mod 1000) div 100));
      end;

   op := Trim(CharBufferBytes(aQso.ceOperator));
   if op <> '' then
      begin
      Result := Result + ' ' + op;
      end;
end;

end.

{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 }

{ ContestExchange <-> a row in qso.  THE MAPPER, AND NOTHING ELSE.

  WHY A REPOSITORY AND NOT A RECORD THAT SAVES ITSELF.  NY4I, 2026-09-01, on
  being shown the mapper plan: "My original idea about a QSO class is inexorably
  linked to the database. Having an in-between stop does not buy us anything...
  otherwise there is throwaway code."

  Fair, and the answer is the shape rather than the order. With Active Record --
  the QSO object persisting itself -- this code WOULD move when ContestExchange
  becomes a class, and the objection holds. With a repository it does not:

      SaveQSO(const aQso: ContestExchange)   today
      SaveQSO(const aQso: TContestQSO)       after the contest factory

  a parameter type, not a rewrite. The expensive part -- 71 field decisions, the
  enum encodings, the sentinel rules -- is identical either way and stays here.

  It is also what TR4QT does, which is worth knowing precisely because it cuts
  against the instinct: struct QSO is a plain VALUE TYPE that does not persist
  itself, and QSORepository::saveQSO saves it. Section 4e of the schema plan
  reaches the same answer independently, from the aliasing hazard -- a record
  assignment copies, a class assignment aliases, and Pascal reports neither.

  THE FIELD MAPPING IS docs\CONTEST_EXCHANGE_CROSSWALK.md, all 71 of them. Three
  of its findings are load-bearing here and each is a defect if ignored:

  1. THE RECORD HAS NO SENT-EXCHANGE FIELD. exchange_sent is left alone by this
     unit -- it is filled at log time (Phase C), and that is issue #2.

  2. ELEVEN rcvd_* COLUMNS HAVE NO RECORD SOURCE, because the record carries one
     polymorphic QTHString. This unit stores the LITERAL and does not guess which
     of rcvd_grid / rcvd_state / rcvd_park it was: guessing would mean the mapper
     knowing the contest, which is the fusion the migration order exists to
     avoid. The contest factory enriches later.

  3. A SENTINEL IS NOT A VALUE. ClearContestExchange writes -1, MAXBYTE and
     MAXWORD for "not set", so writing them through would put zone 255 and
     Ten-Ten 65535 into every contest that uses neither. They become NULL, and
     NULL becomes the sentinel again on the way back. }
unit uLogRepository;

{$I tr4w.inc}

interface

uses
   { Windows for MAXBYTE / MAXWORD, which are the sentinels
     ClearContestExchange writes. DateUtils for the unix epoch. }
   Windows, Classes, SysUtils, DateUtils, db, sqldb, VC, uLogDatabase;

type
   ELogRepositoryError = class(Exception);

   { Reads and writes QSOs.  Owns its prepared statements and nothing else --
     the connection belongs to the TLogDatabase handed in. }
   TLogRepository = class(TObject)
   private
      FDatabase: TLogDatabase;
      FInsert: TSQLQuery;
      FSelect: TSQLQuery;
      FLastGuid: AnsiString;

      FUpdate: TSQLQuery;
      FSelectById: TSQLQuery;

      procedure PrepareStatements;
      procedure BindInto(aQuery: TSQLQuery; const aQso: ContestExchange;
                         const aGuid: AnsiString; aWithGuid: boolean);
      procedure BindRecord(const aQso: ContestExchange; const aGuid: AnsiString);
      procedure BindUpdate(const aQso: ContestExchange);
      procedure ReadRecord(aQuery: TSQLQuery; out aQso: ContestExchange);
   public
      constructor Create(aDatabase: TLogDatabase);
      destructor Destroy; override;

      { Appends a QSO and returns ITS ROW ID -- the handle everything else uses.

        THE ROW IDENTITY IS qso.id, AND THAT WAS MEASURED RATHER THAN CHOSEN.
        The obvious candidate was (ceQSOID1, ceQSOID2), because uNet's
        FindAndUpdateQSOInLog already finds a QSO to update by matching exactly
        that pair. It is not unique: across four corpus logs it gave 3 distinct
        pairs for 1,316 rows, 2 for 206, and in winter_fd 1,314 of 1,316 rows
        are (0, 0). The pair is stamped only on the network path, so that
        function is right for ITS job and useless as a general handle -- keying
        an update on it would have matched 1,314 rows at once.

        Does NOT commit; the caller decides the batch. }
      function SaveQSO(const aQso: ContestExchange): Int64;

      { The guid the last SaveQSO stored, for anything that wants the durable
        identity rather than the row handle. }
      property LastGuid: AnsiString read FLastGuid;

      { REPLACES the row.  Every column BindRecord writes is rewritten, so a
        partially-populated record blanks what it does not carry -- which is
        what the file-based code does too, since it rewrites the whole record.
        False when there is no such row. }
      function UpdateQSO(aRowId: Int64; const aQso: ContestExchange): boolean;

      { The newest row, which is what the three "seek back one record" sites
        want: DeleteLastContact, uNet.UpdateRec and uQTCS.SetSendedQSOs all
        rewrite the record they have just written. }
      function NewestRowId: Int64;

      function LoadQSO(aRowId: Int64; out aQso: ContestExchange): boolean;

      { By the guid rather than the row.  Kept because the guid is the identity
        that survives an export and a re-import, where a row id does not. }
      function LoadQSOByGuid(const aGuid: AnsiString; out aQso: ContestExchange): boolean;

      { Non-deleted QSOs, counted by the database rather than tracked here --
        section 9a: no stored derived values, no in-memory mirror. }
      function QSOCount: integer;

      procedure Commit;

      property Database: TLogDatabase read FDatabase;
   end;

{ A UUIDv7: 48-bit big-endian millisecond timestamp, version 7, then random.
  Question 5 of the schema plan settled v7 over v4 -- it sorts by creation time,
  so a log's rows cluster in insertion order on disk and a chooser can order by
  guid without a second column.

  aUnixMillis lets the IMPORTER stamp a QSO's own time rather than the moment of
  import, so an imported log sorts the way it was made. }
function NewUUIDv7(aUnixMillis: Int64): AnsiString;

{ THE ROW'S OWN guid, ALWAYS FRESH.

  It would be tempting to reuse ContestExchange.id when the record has one, and
  the first version did. IT IS WRONG, and the corpus proved it: `id` identifies
  the EXCHANGE, not the QSO. A county-line contact is one exchange logged as
  several QSOs, and they share the id -- two W4THY rows in
  florida_qp_2026_ny4i both carry 5cd6c61f69cf4422baef44f93b2cbbd2. Reusing it
  violates the unique key on the second QSO of any county line.

  The record's id is preserved separately, in exchange_id, where two rows
  sharing it is a fact rather than a collision.

  Stamped with the QSO's own time so an imported log sorts the way it was made
  rather than the way it was imported. }
function NewRowGuid(const aQso: ContestExchange): AnsiString;

{ ceOperator is array[0..10] of AnsiChar, and a cast between a fixed buffer
  and a managed string is NOT a conversion -- see the implementation.
  Exported because anything comparing or displaying that field needs the same
  NUL-aware reading, and a second hand-rolled loop is how the two drift. }
function CharArrayToAnsi(const aBuffer: array of AnsiChar): AnsiString;
procedure AnsiToCharArray(var aBuffer: array of AnsiChar; const aValue: AnsiString);

implementation

uses
   uADIF, uLogBinaryFile, ZONECONT;

{ --------------------------------------------------------------------------- }
{ sentinels -- crosswalk finding 3                                            }
{ --------------------------------------------------------------------------- }

{ Each of these takes the value and the marker ClearContestExchange uses for
  "not set", and yields NULL for it.  Written as four small functions rather
  than inline tests because the sentinel differs per field and an inline `if`
  repeated forty times is where one of them gets the wrong constant. }

procedure BindByte(aParam: TParam; aValue: byte; aSentinel: byte);
begin
   if aValue = aSentinel then
      begin
      aParam.Clear;      { NULL }
      end
   else
      begin
      aParam.AsInteger := aValue;
      end;
end;

procedure BindWord(aParam: TParam; aValue: word; aSentinel: word);
begin
   if aValue = aSentinel then
      begin
      aParam.Clear;
      end
   else
      begin
      aParam.AsInteger := aValue;
      end;
end;

procedure BindSerial(aParam: TParam; aValue: integer);
begin
   { -1, not 0. ClearContestExchange sets NumberSent and NumberReceived to -1,
     and 0 is a legal serial in some contests. }
   if aValue = -1 then
      begin
      aParam.Clear;
      end
   else
      begin
      aParam.AsInteger := aValue;
      end;
end;

procedure BindText(aParam: TParam; const aValue: AnsiString);
begin
   { An empty ShortString and a NULL are the same absence. Storing '' would make
     `WHERE rcvd_grid IS NULL` and `= ''` disagree about the same QSO. }
   if aValue = '' then
      begin
      aParam.Clear;
      end
   else
      begin
      aParam.AsString := aValue;
      end;
end;

{ ceOperator IS array[0..10] of AnsiChar, NOT a ShortString.

  `AnsiString(aQso.ceOperator)` and `OperatorType(someAnsiString)` both COMPILE
  and both are wrong, which is the whole hazard: the first takes all eleven
  bytes including the NUL padding, and the second is a pointer cast that
  dereferences the string's data -- so an EMPTY AnsiString, whose data pointer
  is nil, faults. Found by a test whose QSO simply had no operator (2026-09-01),
  which is the ordinary case for a single-op log.

  This is the same class CLAUDE.md warns about at Win32 boundaries: a cast
  between a fixed buffer and a managed string is not a conversion. }

{ OPEN ARRAYS, NOT UNTYPED POINTERS. NY4I, 2026-09-01: "no artifacts of win32
  string handling when we are done -- no PChar, string pointers, s[1] type
  stuff. All native FPC/LAZ."

  The first version took `const aBuffer` untyped and walked it with a PAnsiChar,
  which is the Win32 habit this tree is unwinding. An open array says the same
  thing in the language: the compiler passes the bounds, Low and High are real,
  and there is no address arithmetic to get wrong.

  These exist at all because ContestExchange.ceOperator is
  array[0..10] of AnsiChar -- a fixed buffer in a record designed in the
  nineties. When the contest factory turns that record into a class the field
  becomes a string and both routines can go. }
function CharArrayToAnsi(const aBuffer: array of AnsiChar): AnsiString;
var
   i: integer;
begin
   Result := '';
   for i := Low(aBuffer) to High(aBuffer) do
      begin
      { NUL ends it. The rest is padding, and taking all eleven bytes is exactly
        what an AnsiString() cast of the field would wrongly do. }
      if aBuffer[i] = #0 then
         begin
         Exit;
         end;
      Result := Result + aBuffer[i];
      end;
end;

procedure AnsiToCharArray(var aBuffer: array of AnsiChar; const aValue: AnsiString);
var
   i: integer;
begin
   for i := Low(aBuffer) to High(aBuffer) do
      begin
      if i < Length(aValue) then
         begin
         aBuffer[i] := aValue[i + 1];
         end
      else
         begin
         { NUL padding, so the tail is not whatever was there before. }
         aBuffer[i] := #0;
         end;
      end;
end;

procedure BindBool(aParam: TParam; aValue: boolean);
begin
   if aValue then
      begin
      aParam.AsInteger := 1;
      end
   else
      begin
      aParam.AsInteger := 0;
      end;
end;

function FieldByte(aField: TField; aSentinel: byte): byte;
begin
   if aField.IsNull then
      begin
      Result := aSentinel;
      end
   else
      begin
      Result := byte(aField.AsInteger);
      end;
end;

function FieldWord(aField: TField; aSentinel: word): word;
begin
   if aField.IsNull then
      begin
      Result := aSentinel;
      end
   else
      begin
      Result := word(aField.AsInteger);
      end;
end;

function FieldSerial(aField: TField): integer;
begin
   if aField.IsNull then
      begin
      Result := -1;
      end
   else
      begin
      Result := aField.AsInteger;
      end;
end;

function FieldBool(aField: TField): boolean;
begin
   Result := (not aField.IsNull) and (aField.AsInteger <> 0);
end;

{ --------------------------------------------------------------------------- }
{ enum tokens -- the SAME arrays ADIF export uses                             }
{ --------------------------------------------------------------------------- }

{ Deliberately not a second set of spellings. ADIFBANDSTRINGSARRAY,
  ADIFModeString and ExtendedModeStringArray are what the exporter emits, so a
  log's band column reads the same as its ADIF file, and there is one table to
  get wrong instead of two. The inverses are uADIF's GetADIFBand / GetADIFMode
  for the same reason. }

function BandToken(aBand: BandType): AnsiString;
begin
   if ADIFBANDSTRINGSARRAY[aBand] = nil then
      begin
      Result := '';
      end
   else
      begin
      Result := AnsiString(ADIFBANDSTRINGSARRAY[aBand]);
      end;
end;

function ModeToken(aMode: ModeType): AnsiString;
begin
   Result := AnsiString(ADIFModeString[aMode]);
end;

function ExtModeToken(aMode: ExtendedModeType): AnsiString;
begin
   Result := AnsiString(ExtendedModeStringArray[aMode]);
end;

{ THE INVERSE OF ADIFModeString, BY SCANNING IT -- not uADIF.GetADIFMode.

  That is not duplication, it is a different contract. GetADIFMode maps ADIF
  MODE NAMES (and several TR4W-specific extended modes) onto a TR4W mode, which
  is what an ADIF importer needs. It does not accept 'DIGITAL', the string
  ADIFModeString[Digital] actually contains -- so a Digital QSO written by this
  mapper came back as NoMode. Measured: nine corpus QSOs across florida_qp and
  arrl_fd, 2026-09-01.

  Deriving the inverse from the same array is what makes the pair correct by
  construction, the way uRadioRegistry.RadioTypeToken does for radios. }
function TokenToMode(const aToken: AnsiString): ModeType;
var
   m: ModeType;
   tok: string;
begin
   Result := NoMode;
   if aToken = '' then
      begin
      Exit;
      end;
   { Widened ONCE. Comparing an AnsiString against a UnicodeString picks the
     Ansi overload of SameText and narrows BOTH arguments at every iteration,
     which the build counts and which is lossy for anything outside the ANSI
     codepage -- neither is wanted for what is really an ASCII token match. }
   tok := UpperCase(string(aToken));
   for m := Low(ModeType) to High(ModeType) do
      begin
      { UpperCase and '=' rather than SameText: SameText resolves to its
        AnsiString overload even when both arguments are UnicodeString, and
        narrows them back at every iteration. These are ASCII tokens we wrote
        ourselves, so an uppercase compare is exact. }
      if UpperCase(string(AnsiString(ADIFModeString[m]))) = tok then
         begin
         Result := m;
         Exit;
         end;
      end;
end;

function TokenToExtMode(const aToken: AnsiString): ExtendedModeType;
var
   m: ExtendedModeType;
   tok: string;
begin
   { Derived by scanning the same array rather than kept as a second table --
     the trick uRadioRegistry.RadioTypeToken uses, which makes drift
     unrepresentable rather than merely fixed. }
   Result := eNoMode;
   if aToken = '' then
      begin
      Exit;
      end;
   tok := UpperCase(string(aToken));
   for m := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      if UpperCase(ExtendedModeStringArray[m]) = tok then
         begin
         Result := m;
         Exit;
         end;
      end;
end;

function RecordKindToken(aKind: LogRecordKind): AnsiString;
begin
   case aKind of
      rkQSO:  Result := 'QSO';
      rkQTCR: Result := 'QTCR';
      rkQTCS: Result := 'QTCS';
      rkNote: Result := 'NOTE';
   else
      Result := 'QSO';
   end;
end;

function TokenToRecordKind(const aToken: AnsiString): LogRecordKind;
begin
   if aToken = 'QTCR' then
      begin
      Result := rkQTCR;
      end
   else if aToken = 'QTCS' then
      begin
      Result := rkQTCS;
      end
   else if aToken = 'NOTE' then
      begin
      Result := rkNote;
      end
   else
      begin
      Result := rkQSO;
      end;
end;

{ --------------------------------------------------------------------------- }
{ identity                                                                     }
{ --------------------------------------------------------------------------- }

function NewUUIDv7(aUnixMillis: Int64): AnsiString;
var
   b: array[0..15] of byte;
   i: integer;
   ms: Int64;
begin
   ms := aUnixMillis;
   if ms <= 0 then
      begin
      ms := DateTimeToUnix(Now) * Int64(1000);
      end;

   { 48-bit big-endian timestamp. }
   for i := 0 to 5 do
      begin
      b[i] := byte((ms shr ((5 - i) * 8)) and $FF);
      end;

   for i := 6 to 15 do
      begin
      b[i] := byte(Random(256));
      end;

   b[6] := (b[6] and $0F) or $70;   { version 7 }
   b[8] := (b[8] and $3F) or $80;   { variant 10 }

   { NO DASHES -- 32 lowercase hex characters.

     Not a style choice: ContestExchange.id is string[32], so the canonical
     36-character form does not fit and a round trip silently truncates it,
     which is how the first version failed its own stability test. TF.GetGUID
     already returns "32-char lowercase hex, no dashes" for the same field, so
     this matches what every existing id in every existing log looks like. }
   Result := '';
   for i := 0 to 15 do
      begin
      Result := Result + AnsiString(LowerCase(IntToHex(b[i], 2)));
      end;
end;

function NewRowGuid(const aQso: ContestExchange): AnsiString;
begin
   Result := NewUUIDv7(QSOTimeToUnixUTC(aQso.tSysTime) * Int64(1000));
end;

{ --------------------------------------------------------------------------- }
{ TLogRepository                                                               }
{ --------------------------------------------------------------------------- }

const
   { Named once. Adding a column means adding it here, in BindRecord and in
     ReadRecord, and the round-trip test fails if the three disagree. }
   QSO_COLUMNS =
      'guid, exchange_id, session_id, session_seq, computer_id, operator_id, record_kind, ' +
      'qso_at, callsign, standard_call, freq_tx_hz, band, mode, submode, ' +
      'exchange_received, rst_sent, rst_received, serial_sent, serial_received, ' +
      'rcvd_zone, rcvd_name, rcvd_age, rcvd_check, rcvd_precedence, rcvd_class, ' +
      'rcvd_power, rcvd_chapter, rcvd_prefecture, rcvd_member_no, rcvd_qth, ' +
      'rcvd_random, random_sent, rcvd_kids, qtc_call, domestic_qth, ' +
      'dxcc_prefix, dxcc_entity, dxcc_code, cty_cq_zone, cty_continent, ' +
      'prefix_mult, dx_mult, domestic_mult, ' +
      'mult_domestic, mult_dx, mult_prefix, mult_zone, inhibit_mults, ' +
      'qso_points, is_dupe, is_run, is_xqso, is_skipped, sent_in_qtc, ' +
      'name_sent, mp3_recorded, clear_dupe_sheet, clear_mult_sheet, ' +
      'radio_nr, operator_call, deleted, sent_to_server, server_dirty';

   { The same list without the guid -- see PrepareStatements for why. }
   QSO_COLUMNS_NO_GUID =
      'exchange_id, session_id, session_seq, computer_id, operator_id, record_kind, ' +
      'qso_at, callsign, standard_call, freq_tx_hz, band, mode, submode, ' +
      'exchange_received, rst_sent, rst_received, serial_sent, serial_received, ' +
      'rcvd_zone, rcvd_name, rcvd_age, rcvd_check, rcvd_precedence, rcvd_class, ' +
      'rcvd_power, rcvd_chapter, rcvd_prefecture, rcvd_member_no, rcvd_qth, ' +
      'rcvd_random, random_sent, rcvd_kids, qtc_call, domestic_qth, ' +
      'dxcc_prefix, dxcc_entity, dxcc_code, cty_cq_zone, cty_continent, ' +
      'prefix_mult, dx_mult, domestic_mult, ' +
      'mult_domestic, mult_dx, mult_prefix, mult_zone, inhibit_mults, ' +
      'qso_points, is_dupe, is_run, is_xqso, is_skipped, sent_in_qtc, ' +
      'name_sent, mp3_recorded, clear_dupe_sheet, clear_mult_sheet, ' +
      'radio_nr, operator_call, deleted, sent_to_server, server_dirty';

   QSO_PARAMS =
      ':guid, :exchange_id, :session_id, :session_seq, :computer_id, :operator_id, :record_kind, ' +
      ':qso_at, :callsign, :standard_call, :freq_tx_hz, :band, :mode, :submode, ' +
      ':exchange_received, :rst_sent, :rst_received, :serial_sent, :serial_received, ' +
      ':rcvd_zone, :rcvd_name, :rcvd_age, :rcvd_check, :rcvd_precedence, :rcvd_class, ' +
      ':rcvd_power, :rcvd_chapter, :rcvd_prefecture, :rcvd_member_no, :rcvd_qth, ' +
      ':rcvd_random, :random_sent, :rcvd_kids, :qtc_call, :domestic_qth, ' +
      ':dxcc_prefix, :dxcc_entity, :dxcc_code, :cty_cq_zone, :cty_continent, ' +
      ':prefix_mult, :dx_mult, :domestic_mult, ' +
      ':mult_domestic, :mult_dx, :mult_prefix, :mult_zone, :inhibit_mults, ' +
      ':qso_points, :is_dupe, :is_run, :is_xqso, :is_skipped, :sent_in_qtc, ' +
      ':name_sent, :mp3_recorded, :clear_dupe_sheet, :clear_mult_sheet, ' +
      ':radio_nr, :operator_call, :deleted, :sent_to_server, :server_dirty';

{ 'a, b, c' -> 'a = :a, b = :b, c = :c'.

  DERIVED FROM QSO_COLUMNS rather than written out, so the insert and the update
  cannot drift. A hand-maintained second list is how an update quietly stops
  writing a column that the insert writes -- the row would look right on
  creation and lose the field on the first edit. }
{ TYPED AnsiString CONSTANTS, not literals.

  An untyped literal is UnicodeString here -- tr4w.inc makes `string` UTF-16 --
  so concatenating one with an AnsiString narrows, and `AnsiString('x')` does NOT
  help: the literal is still built as UnicodeString and then converted, which is
  the very conversion being counted. A typed constant is compiled as AnsiString
  from the start. }
const
   COMMA_SEP:  AnsiString = ', ';
   EQUALS_BIND: AnsiString = ' = :';
   UPDATE_HEAD: AnsiString = 'UPDATE qso SET ';
   UPDATE_TAIL: AnsiString = ' WHERE id = :row_id';

function AssignmentsFor(const aColumns: AnsiString): AnsiString;
var
   i: integer;
   name: AnsiString;

   procedure Emit;
   begin
      if name = '' then
         begin
         Exit;
         end;
      if Result <> '' then
         begin
         Result := Result + COMMA_SEP;
         end;
      Result := Result + name + EQUALS_BIND + name;
      name := '';
   end;

begin
   { Split by hand rather than with StrUtils' WordCount/ExtractWord: those take
     UnicodeString here, so every column name would round-trip through a
     narrowing conversion for no reason. The separator is one character and the
     input is our own constant. }
   Result := '';
   name := '';
   for i := 1 to Length(aColumns) do
      begin
      if aColumns[i] = ',' then
         begin
         Emit;
         end
      else if aColumns[i] <> ' ' then
         begin
         name := name + aColumns[i];
         end;
      end;
   Emit;
end;

constructor TLogRepository.Create(aDatabase: TLogDatabase);
begin
   inherited Create;
   if (aDatabase = nil) or (not aDatabase.IsOpen) then
      begin
      raise ELogRepositoryError.Create(
         'A log repository needs an open contest log.');
      end;
   FDatabase := aDatabase;
   PrepareStatements;
end;

destructor TLogRepository.Destroy;
begin
   FInsert.Free;
   FSelect.Free;
   FSelectById.Free;
   FUpdate.Free;
   inherited Destroy;
end;

{ PREPARED ONCE, RE-EXECUTED WITH PARAMETERS -- section 9b. Re-assigning
  SQL.Text per call throws the plan away and re-parses, which is the mistake
  that makes people conclude they need a cache. }
procedure TLogRepository.PrepareStatements;
begin
   FInsert := TSQLQuery.Create(nil);
   FInsert.DataBase := FDatabase.Connection;
   FInsert.SQL.Text := 'INSERT INTO qso (' + QSO_COLUMNS + ') VALUES (' +
                       QSO_PARAMS + ')';
   FInsert.Prepare;

   FSelect := TSQLQuery.Create(nil);
   FSelect.DataBase := FDatabase.Connection;
   FSelect.SQL.Text := 'SELECT ' + QSO_COLUMNS + ' FROM qso WHERE guid = :guid';
   FSelect.Prepare;

   FSelectById := TSQLQuery.Create(nil);
   FSelectById.DataBase := FDatabase.Connection;
   FSelectById.SQL.Text := 'SELECT ' + QSO_COLUMNS + ' FROM qso WHERE id = :row_id';
   FSelectById.Prepare;

   { guid is NOT in the SET clause: a row's identity does not change when its
     contents do, and rewriting it would break anything holding the old one. }
   FUpdate := TSQLQuery.Create(nil);
   FUpdate.DataBase := FDatabase.Connection;
   FUpdate.SQL.Text := UPDATE_HEAD +
                       AssignmentsFor(QSO_COLUMNS_NO_GUID) +
                       UPDATE_TAIL;
   FUpdate.Prepare;
end;

{ ONE BINDER FOR BOTH STATEMENTS.

  BindUpdate calls this against FUpdate, so the insert and the update cannot
  populate different sets of columns -- which is the defect that would show as
  a field surviving creation and vanishing on the first edit. The only
  difference is the guid, which an update must not touch: a row's identity does
  not change when its contents do. }
procedure TLogRepository.BindInto(aQuery: TSQLQuery;
                                  const aQso: ContestExchange;
                                  const aGuid: AnsiString;
                                  aWithGuid: boolean);

   { AnsiString, because that is what ParamByName takes. Declaring it `string`
     narrowed on every one of sixty-odd binds. }
   function P(const aName: AnsiString): TParam;
   begin
      Result := aQuery.ParamByName(aName);
   end;

begin
   if aWithGuid then
      begin
      P('guid').AsString := aGuid;
      end;
   BindText(P('exchange_id'), AnsiString(aQso.id));

   { Identity. session_id/session_seq are ceQSOID1/ceQSOID2 -- the pair
     tr4wserver matches on, and how WAE links a QTC to its QSO. }
   P('session_id').AsLargeInt := aQso.ceQSOID1;
   P('session_seq').AsLargeInt := aQso.ceQSOID2;
   BindText(P('computer_id'), AnsiString(aQso.ceComputerID));
   P('operator_id').AsInteger := aQso.ceOperatorID;
   P('record_kind').AsString := RecordKindToken(aQso.ceRecordKind);

   P('qso_at').AsLargeInt := QSOTimeToUnixUTC(aQso.tSysTime);
   BindText(P('callsign'), AnsiString(aQso.Callsign));
   BindText(P('standard_call'), AnsiString(aQso.QTH.StandardCall));
   P('freq_tx_hz').AsLargeInt := aQso.Frequency;
   BindText(P('band'), BandToken(aQso.Band));
   BindText(P('mode'), ModeToken(aQso.Mode));
   BindText(P('submode'), ExtModeToken(aQso.ExtMode));

   { The received exchange as rendered. There is no sent counterpart in the
     record -- crosswalk finding 1. }
   BindText(P('exchange_received'), AnsiString(aQso.ExchString));

   P('rst_sent').AsInteger := aQso.RSTSent;
   P('rst_received').AsInteger := aQso.RSTReceived;
   BindSerial(P('serial_sent'), aQso.NumberSent);
   BindSerial(P('serial_received'), aQso.NumberReceived);

   BindByte(P('rcvd_zone'), aQso.Zone, DUMMYZONE);
   BindText(P('rcvd_name'), AnsiString(aQso.Name));
   P('rcvd_age').AsInteger := aQso.Age;
   P('rcvd_check').AsInteger := aQso.Check;
   BindText(P('rcvd_precedence'), AnsiString(aQso.Precedence));
   BindText(P('rcvd_class'), AnsiString(aQso.ceClass));
   BindText(P('rcvd_power'), AnsiString(aQso.Power));
   BindText(P('rcvd_chapter'), AnsiString(aQso.Chapter));
   BindByte(P('rcvd_prefecture'), aQso.Prefecture, MAXBYTE);
   BindWord(P('rcvd_member_no'), aQso.TenTenNum, MAXWORD);

   { THE POLYMORPHIC ONE. Stored as the literal it is; the contest factory
     decides later whether it was a grid, a section or a park. }
   BindText(P('rcvd_qth'), AnsiString(aQso.QTHString));

   BindText(P('rcvd_random'), AnsiString(aQso.RandomCharsReceived));
   BindText(P('random_sent'), AnsiString(aQso.RandomCharsSent));

   { Kids is overloaded by record kind -- crosswalk. For a QTC it is the call
     inside the traffic, which is not the station in `callsign`. }
   if aQso.ceRecordKind in [rkQTCR, rkQTCS] then
      begin
      P('rcvd_kids').Clear;
      BindText(P('qtc_call'), AnsiString(aQso.Kids));
      end
   else
      begin
      BindText(P('rcvd_kids'), AnsiString(aQso.Kids));
      P('qtc_call').Clear;
      end;

   BindText(P('domestic_qth'), AnsiString(aQso.DomesticQTH));

   { CTY.DAT-derived, stored so a later CTY.DAT cannot rewrite history. }
   BindText(P('dxcc_prefix'), AnsiString(aQso.QTH.Prefix));
   BindText(P('dxcc_entity'), AnsiString(aQso.QTH.CountryID));
   BindWord(P('dxcc_code'), aQso.QTH.Country, UNKNOWN_COUNTRY);
   BindByte(P('cty_cq_zone'), aQso.QTH.Zone, DUMMYZONE);
   if aQso.QTH.Continent = UnknownContinent then
      begin
      P('cty_continent').Clear;
      end
   else
      begin
      { ContinentTypeSA, NOT tContinentArray.

        tContinentArray is the DISPLAY table: filled at run time by
        InitializeStringTables and TRANSLATABLE -- it used to hold the TC_C9_*
        constants. Using it here would have written blanks in any program that
        had not called InitializeStringTables (which is how the first
        round-trip test failed: every continent came back Unknown) and Spanish
        continent names in a Spanish build.

        A STORAGE TOKEN MUST NOT BE A DISPLAY STRING. ContinentTypeSA is the
        stable two-letter code -- 'NA', 'EU' -- which is also exactly what
        GetContinentFromString parses, so the pair round-trips by construction. }
      P('cty_continent').AsString := AnsiString(ContinentTypeSA[aQso.QTH.Continent]);
      end;

   { The multiplier strings as counted, and the outcome flags. }
   BindText(P('prefix_mult'), AnsiString(aQso.Prefix));
   BindText(P('dx_mult'), AnsiString(aQso.DXQTH));
   BindText(P('domestic_mult'), AnsiString(aQso.DomMultQTH));
   BindBool(P('mult_domestic'), aQso.DomesticMult);
   BindBool(P('mult_dx'), aQso.DXMult);
   BindBool(P('mult_prefix'), aQso.PrefixMult);
   BindBool(P('mult_zone'), aQso.ZoneMult);
   BindBool(P('inhibit_mults'), aQso.InhibitMults);

   P('qso_points').AsInteger := aQso.QSOPoints;
   BindBool(P('is_dupe'), aQso.ceDupe);

   { INVERTED. is_run is the opposite of ceSearchAndPounce, and a straight copy
     would be wrong in a way nothing reports. }
   BindBool(P('is_run'), not aQso.ceSearchAndPounce);

   BindBool(P('is_xqso'), aQso.ceXQSO);
   BindBool(P('is_skipped'), aQso.ceQSO_Skiped);
   BindBool(P('sent_in_qtc'), aQso.ceWasSendInQTC);
   BindBool(P('name_sent'), aQso.NameSent);
   BindBool(P('mp3_recorded'), aQso.MP3Record);
   BindBool(P('clear_dupe_sheet'), aQso.ceClearDupeSheet);
   BindBool(P('clear_mult_sheet'), aQso.ceClearMultSheet);

   P('radio_nr').AsInteger := Ord(aQso.ceRadio);
   BindText(P('operator_call'), CharArrayToAnsi(aQso.ceOperator));
   BindBool(P('deleted'), aQso.ceQSO_Deleted);
   BindBool(P('sent_to_server'), aQso.ceSendToServer);
   BindBool(P('server_dirty'), aQso.ceNeedSendToServerAE);
end;

procedure TLogRepository.BindRecord(const aQso: ContestExchange;
                                    const aGuid: AnsiString);
begin
   BindInto(FInsert, aQso, aGuid, True);
end;

procedure TLogRepository.BindUpdate(const aQso: ContestExchange);
begin
   BindInto(FUpdate, aQso, '', False);
end;

procedure TLogRepository.ReadRecord(aQuery: TSQLQuery; out aQso: ContestExchange);
var
   continentToken: Str20;
   token: AnsiString;

   function F(const aName: AnsiString): TField;
   begin
      Result := aQuery.FieldByName(aName);
   end;

   function S(const aName: AnsiString): AnsiString;
   begin
      if F(aName).IsNull then
         begin
         Result := '';
         end
      else
         begin
         Result := AnsiString(F(aName).AsString);
         end;
   end;

begin
   { EVERY read starts from ClearContestExchange's shape, so a column this unit
     does not restore holds the same "not set" marker the program expects rather
     than a zero that looks like data. }
   FillChar(aQso, SizeOf(aQso), 0);
   aQso.Band := NoBand;
   aQso.Mode := NoMode;
   aQso.ExtMode := eNoMode;
   aQso.NumberReceived := -1;
   aQso.NumberSent := -1;
   aQso.Prefecture := MAXBYTE;
   aQso.QTH.Zone := DUMMYZONE;
   aQso.Zone := DUMMYZONE;
   aQso.QTH.Continent := UnknownContinent;
   aQso.QTH.Country := UNKNOWN_COUNTRY;
   aQso.TenTenNum := MAXWORD;

   aQso.id := S('exchange_id');
   aQso.ceQSOID1 := Cardinal(F('session_id').AsLargeInt);
   aQso.ceQSOID2 := Cardinal(F('session_seq').AsLargeInt);
   { A single character out of a text column. Indexing a managed string is
     ordinary Pascal -- what this tree is removing is taking its ADDRESS. Read
     once into a local so the guard and the use cannot disagree. }
   token := S('computer_id');
   if token <> '' then
      begin
      aQso.ceComputerID := token[1];
      end;
   aQso.ceOperatorID := byte(F('operator_id').AsInteger);
   aQso.ceRecordKind := TokenToRecordKind(S('record_kind'));

   aQso.tSysTime := UnixUTCToQSOTime(F('qso_at').AsLargeInt);
   aQso.Callsign := S('callsign');
   aQso.QTH.StandardCall := S('standard_call');
   aQso.Frequency := F('freq_tx_hz').AsLargeInt;

   { GetADIFBand IS the inverse of ADIFBANDSTRINGSARRAY -- it scans that very
     array -- so it is the right routine and there is no second table. }
   aQso.Band := GetADIFBand(string(S('band')));
   aQso.Mode := TokenToMode(S('mode'));
   aQso.ExtMode := TokenToExtMode(S('submode'));

   aQso.ExchString := S('exchange_received');

   aQso.RSTSent := F('rst_sent').AsInteger;
   aQso.RSTReceived := F('rst_received').AsInteger;
   aQso.NumberSent := FieldSerial(F('serial_sent'));
   aQso.NumberReceived := FieldSerial(F('serial_received'));

   aQso.Zone := FieldByte(F('rcvd_zone'), DUMMYZONE);
   aQso.Name := S('rcvd_name');
   aQso.Age := byte(F('rcvd_age').AsInteger);
   aQso.Check := byte(F('rcvd_check').AsInteger);
   token := S('rcvd_precedence');
   if token <> '' then
      begin
      aQso.Precedence := token[1];
      end;
   aQso.ceClass := S('rcvd_class');
   aQso.Power := S('rcvd_power');
   aQso.Chapter := S('rcvd_chapter');
   aQso.Prefecture := FieldByte(F('rcvd_prefecture'), MAXBYTE);
   aQso.TenTenNum := FieldWord(F('rcvd_member_no'), MAXWORD);
   aQso.QTHString := S('rcvd_qth');
   aQso.RandomCharsReceived := S('rcvd_random');
   aQso.RandomCharsSent := S('random_sent');

   if aQso.ceRecordKind in [rkQTCR, rkQTCS] then
      begin
      aQso.Kids := S('qtc_call');
      end
   else
      begin
      aQso.Kids := S('rcvd_kids');
      end;

   aQso.DomesticQTH := S('domestic_qth');

   aQso.QTH.Prefix := S('dxcc_prefix');
   aQso.QTH.CountryID := S('dxcc_entity');
   aQso.QTH.Country := FieldWord(F('dxcc_code'), UNKNOWN_COUNTRY);
   aQso.QTH.Zone := FieldByte(F('cty_cq_zone'), DUMMYZONE);
   if S('cty_continent') <> '' then
      begin
      begin
      continentToken := S('cty_continent');
      aQso.QTH.Continent := GetContinentFromString(continentToken);
      end;
      end;

   aQso.Prefix := S('prefix_mult');
   aQso.DXQTH := S('dx_mult');
   aQso.DomMultQTH := S('domestic_mult');
   aQso.DomesticMult := FieldBool(F('mult_domestic'));
   aQso.DXMult := FieldBool(F('mult_dx'));
   aQso.PrefixMult := FieldBool(F('mult_prefix'));
   aQso.ZoneMult := FieldBool(F('mult_zone'));
   aQso.InhibitMults := FieldBool(F('inhibit_mults'));

   aQso.QSOPoints := word(F('qso_points').AsInteger);
   aQso.ceDupe := FieldBool(F('is_dupe'));
   aQso.ceSearchAndPounce := not FieldBool(F('is_run'));
   aQso.ceXQSO := FieldBool(F('is_xqso'));
   aQso.ceQSO_Skiped := FieldBool(F('is_skipped'));
   aQso.ceWasSendInQTC := FieldBool(F('sent_in_qtc'));
   aQso.NameSent := FieldBool(F('name_sent'));
   aQso.MP3Record := FieldBool(F('mp3_recorded'));
   aQso.ceClearDupeSheet := FieldBool(F('clear_dupe_sheet'));
   aQso.ceClearMultSheet := FieldBool(F('clear_mult_sheet'));

   aQso.ceRadio := RadioType(F('radio_nr').AsInteger);
   AnsiToCharArray(aQso.ceOperator, S('operator_call'));
   aQso.ceQSO_Deleted := FieldBool(F('deleted'));
   aQso.ceSendToServer := FieldBool(F('sent_to_server'));
   aQso.ceNeedSendToServerAE := FieldBool(F('server_dirty'));
end;

function TLogRepository.SaveQSO(const aQso: ContestExchange): Int64;
begin
   FLastGuid := NewRowGuid(aQso);
   BindRecord(aQso, FLastGuid);
   FInsert.ExecSQL;
   Result := NewestRowId;
end;

{ last_insert_rowid() rather than MAX(id): it is per-connection and unaffected by
  anything another connection does, and it is what SQLite provides for exactly
  this. MAX(id) would also be wrong the moment a row is deleted. }
function TLogRepository.NewestRowId: Int64;
var
   q: TSQLQuery;
begin
   Result := 0;
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      q.SQL.Text := 'SELECT last_insert_rowid()';
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsLargeInt;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

function TLogRepository.UpdateQSO(aRowId: Int64;
                                  const aQso: ContestExchange): boolean;
begin
   BindUpdate(aQso);
   FUpdate.ParamByName('row_id').AsLargeInt := aRowId;
   FUpdate.ExecSQL;

   { RowsAffected distinguishes "changed it" from "there was no such row", which
     is the difference between an edit and a silent no-op. The file-based code
     cannot tell those apart -- it seeks and writes -- so this is one thing the
     database does better rather than merely differently. }
   Result := FUpdate.RowsAffected > 0;
end;

function TLogRepository.LoadQSO(aRowId: Int64;
                                out aQso: ContestExchange): boolean;
begin
   FSelectById.Close;
   FSelectById.ParamByName('row_id').AsLargeInt := aRowId;
   FSelectById.Open;
   Result := not FSelectById.EOF;
   if Result then
      begin
      ReadRecord(FSelectById, aQso);
      end
   else
      begin
      FillChar(aQso, SizeOf(aQso), 0);
      end;
   FSelectById.Close;
end;

function TLogRepository.LoadQSOByGuid(const aGuid: AnsiString;
                                      out aQso: ContestExchange): boolean;
begin
   FSelect.Close;
   FSelect.ParamByName('guid').AsString := aGuid;
   FSelect.Open;
   Result := not FSelect.EOF;
   if Result then
      begin
      ReadRecord(FSelect, aQso);
      end
   else
      begin
      FillChar(aQso, SizeOf(aQso), 0);
      end;
   FSelect.Close;
end;

function TLogRepository.QSOCount: integer;
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      q.SQL.Text := 'SELECT COUNT(*) FROM qso WHERE deleted = 0';
      q.Open;
      Result := q.Fields[0].AsInteger;
      q.Close;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.Commit;
begin
   FDatabase.Transaction.Commit;
end;

initialization
   Randomize;

end.

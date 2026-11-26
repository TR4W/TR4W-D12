(*
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
 *)

(* READING A BINARY TR4W LOG -- THE ONE PLACE THAT KNOWS THE ON-DISK LAYOUT.

  Extracted from test\logdump\logdump.lpr on 2026-09-01, BEFORE the SQLite
  importer became its second copy rather than after.  CLAUDE.md: "when you add
  the second caller of something private to a unit, that is the moment to lift
  it out, not later" -- and this reader carries two pieces of knowledge that
  were learned the hard way and would not have survived being re-derived:

  1. A LOG IS header + N * record, EXACTLY, and the record is the frozen
     376-byte TTrwRecordV17 below.  If the file size does not divide, it was
     written in another record size (a v1.5/v1.6 log, or a damaged file), and
     reading at this stride yields MISALIGNED GARBAGE rather than an error.
     Refuse instead.

  2. A SHORT READ AT THE TAIL IS END-OF-FILE, SILENTLY.  That is what the
     legacy ReadLogFile did (MainUnit): it read one record and treated
     "fewer bytes than that" as the end.  Anything stricter reports
     corruption on files TR4W itself considers fine, and anything looser
     invents a record out of trailing bytes.  Real cases: a log written by an
     older TR4W, or a file truncated mid-write.

  WHY IT REPORTS RATHER THAN HALTS.  logdump could call Halt(3) because it is a
  program.  A unit cannot: the importer needs to tell an operator which of his
  logs would not read and carry on with the others.  So every failure is a
  status plus a sentence, and the caller decides.

  WHY TFileStream AND NOT Windows.ReadFile.  The original used the Win32 API
  because it was copied from ReadLogFile.  The semantics that matter -- a short
  read means EOF -- are expressible either way, and TFileStream is RTL, so an
  operator's old .trw can still be imported on macOS or Linux later.  This unit
  needs VC for ContestExchange, which drags in Windows regardless, so there is
  no purity gain today; there is a portability gain the day VC is split. *)
unit uLogBinaryFile;

{$I tr4w.inc}

interface

uses
   Classes, SysUtils, VC;

(* THE D7 v1.7 ON-DISK RECORD, FROZEN (issue 386, batch B, 2026-11-26).

  A .TRW is a header record plus N records of exactly this layout: what D7
  wrote, and what every TR4W up to 5.0.x appended. It was ContestExchange
  itself until this batch -- the reader did one Read of 376 bytes straight into
  the live record -- so the program's QSO record could not change without
  misreading every old log. Now the file format is THIS type and nothing else,
  and ContestExchange is free to change: TrwRecordToQso carries it across field
  by field.

  FROZEN MEANS LITERAL. Every string is written as string[n], the operator as
  an AnsiChar array, every enum as the Byte it is on disk, and the time and QTH
  records are this unit's own copies -- so widening CallString, Str10, an enum
  or QTHRecord in VC can never move a byte here. The offsets and the size are
  pinned against literal numbers in uTestLogBinaryFile, and the size again at
  compile time below. DO NOT EDIT THIS TYPE: there are files on disk in it.

  IT IS A PLAIN record, NOT packed, ON PURPOSE: the layout IS the x86 natural
  alignment D7 used (two pad bytes before NumberReceived, two at the end), and
  the pins say so. The importer is a Windows migration path; on aarch64 the
  natural alignment differs and the pins fail there -- see
  uTestLogBinaryFile, TestTheRecordHasTheSameFIELD_OFFSETSEverywhere.

  WHAT 5.x CARVED OUT OF sReserved IS NOT HERE. RcvdYear, YearSent, the
  off-contest stamp and the rover place were carved from D7's sReserved in the
  live record; no D7 file holds them, so this record keeps D7's sReserved
  (string[49]) and the converter leaves those fields unset. ceXQSO IS here: D7
  itself carved it (D7 issue #750), so a D7 log can carry an X-QSO. *)
type
   TTrwQSOTimeV17 = packed record
      qtYear: Byte;
      qtMonth: Byte;
      qtDay: Byte;
      qtHour: Byte;
      qtMinute: Byte;
      qtSecond: Byte;
   end;

   TTrwQTHRecordV17 = record
      CountryID: string[5];
      Zone: Byte;
      reserved: Byte;
      Prefix: string[6];
      Continent: Byte;              (* ContinentType *)
      StandardCall: string[13];
      Country: Word;
   end;

   TTrwRecordV17 = record
      tSysTime: TTrwQSOTimeV17;
      Band: Byte;                   (* BandType *)
      Mode: Byte;                   (* ModeType *)
      ceQSOID1: Cardinal;
      ceQSOID2: Cardinal;
      Frequency: LongInt;
      ceQSO_Deleted: Boolean;
      ceComputerID: AnsiChar;
      ceOperatorID: Byte;
      ceRecordKind: Byte;           (* LogRecordKind *)
      ceQSO_Skiped: Boolean;        (* the old Alt-Y delete flag; folded into ceQSO_Deleted *)
      ceSendToServer: Boolean;
      ceNeedSendToServerAE: Boolean;
      ceDupe: Boolean;
      PostalCode_old: string[6];
      ZERO_01: Byte;
      Prefix: string[6];            (* a note's 80-byte text region starts here *)
      ZERO_02: Byte;
      Callsign: string[13];
      Age: Byte;
      ceWasSendInQTC: Boolean;
      DomesticMult: Boolean;
      DXMult: Boolean;
      PrefixMult: Boolean;
      ZoneMult: Boolean;
      ExtMode: Byte;                (* ExtendedModeType *)
      ExchString: string[40];
      ceClass: string[3];
      ZERO_04: Byte;
      Precedence: AnsiChar;
      ceRadio: Byte;                (* RadioType *)
      Check: Byte;
      QTH: TTrwQTHRecordV17;
      DXQTH: string[5];
      ZERO_05: Byte;
      Radio: Byte;                  (* InterfacedRadioType *)
      DomMultQTH: string[10];
      ZERO_06: Byte;
      DomesticQTH: string[10];
      ZERO_07: Byte;
      Name: string[10];
      ZERO_08: Byte;
      Power: string[6];
      ZERO_09: Byte;
      NumberReceived: Integer;
      NumberSent: Integer;
      RSTSent: SmallInt;
      RSTReceived: SmallInt;
      QTHString: string[10];
      ZERO_10: Byte;
      RandomCharsSent: string[5];
      TenTenNum: Word;
      Chapter: string[4];
      ZERO_11: Byte;
      ceClearDupeSheet: Boolean;
      ceSearchAndPounce: Boolean;
      Prefecture: Byte;
      InhibitMults: Boolean;
      Zone: Byte;
      NameSent: Boolean;
      Kids: string[20];
      ceContest: Byte;              (* the D7 ContestType ordinal = the legacy contest number *)
      QSOPoints: Word;
      RandomCharsReceived: string[7];
      ZERO_13: Byte;
      ceClearMultSheet: Boolean;
      MP3Record: Boolean;
      ceOperator: array[0..10] of AnsiChar;
      id: string[32];
      ceXQSO: Boolean;
      sReserved: string[49];        (* never written by D7; not carried *)
   end;

   (* THE D7 HEADER: the first record of the file, padded to one record. It was
     VC.TLogHeader, whose padding was SizeOfContestExchange minus the 60 used
     bytes -- so a bigger QSO record would have misread every header. Now it is
     a literal 376, tied to the frozen record by the compile-time check below. *)
   TTrwHeaderV17 = record
      lhVersionString: array[0..7] of AnsiChar;
      lhFileDesc: array[0..15] of AnsiChar;
      lhWarningString: array[0..35] of AnsiChar;
      lhDummy: array[0..315] of AnsiChar;
   end;

const
   (* The size of one record, and of the header, in every .TRW. *)
   TRW_RECORD_SIZE = 376;
   (* A note's text region: NOTE_MAX_LENGTH (uLogNote) bytes from Prefix. Stated
     here again, literally, because this is the FILE's region -- the in-memory
     one may move. *)
   TRW_NOTE_REGION = 80;

{$IF SizeOf(TTrwRecordV17) <> TRW_RECORD_SIZE}
{$ERROR TTrwRecordV17 is not the 376-byte D7 v1.7 record: it is frozen, do not edit it}
{$ENDIF}
{$IF SizeOf(TTrwHeaderV17) <> TRW_RECORD_SIZE}
{$ERROR TTrwHeaderV17 is not one 376-byte record}
{$ENDIF}

(* ONE D7 RECORD -> ONE QSO, FIELD BY FIELD. aQso is cleared first, so every
  field the file does not have (the 5.x ones: the received and sent year, the
  off-contest stamp, the rover place) comes out unset. Also folds the legacy
  delete flag, and carries a note's text, which is a byte region rather than
  fields. NO Move OF THE RECORD: a new field in ContestExchange is unset here
  until someone decides what an old log means for it. *)
procedure TrwRecordToQso(const aTrw: TTrwRecordV17; var aQso: ContestExchange);

(* The text of a note record (rkNote), read from the FILE's region: bytes up to
  the first NUL, or all TRW_NOTE_REGION of them. *)
function TrwNoteText(const aTrw: TTrwRecordV17): AnsiString;

type
   TLogBinaryStatus = (
      lbOK,
      lbCannotOpen,        (* no such file, or locked by a running TR4W *)
      lbTooSmall,          (* smaller than one header *)
      lbStrideMismatch,    (* not header + N * record -- see the header comment *)
      lbHeaderUnreadable
   );

   (* Reads a .trw / .dat sequentially.  One instance per file, forward only --
     which is all the importer and logdump need, and it keeps the short-read
     rule in one place instead of at every seek. *)
   TLogBinaryReader = class(TObject)
   private
      FStream: TFileStream;
      FFileName: string;
      FStatus: TLogBinaryStatus;
      FMessage: string;
      FHeader: TTrwHeaderV17;
      FExpectedRecords: Int64;
      FRecordsRead: Int64;

      procedure ReportFailure(aStatus: TLogBinaryStatus; const aMessage: string);
   public
      (* Opens and validates in one step.  Check Status before reading; a reader
        that failed to open returns False from ReadNext and says why. *)
      constructor Create(const aFileName: string);
      destructor Destroy; override;

      (* False at end of file, and False if the reader never opened.  A short
        read at the tail is end of file, not an error -- see the unit header. *)
      function ReadNext(out aRecord: ContestExchange): boolean;

      property Status: TLogBinaryStatus read FStatus;
      (* Empty when Status is lbOK. Otherwise a sentence for a human. *)
      property Message: string read FMessage;
      property FileName: string read FFileName;
      property Header: TTrwHeaderV17 read FHeader;

      (* 'v1.7' -- the first four bytes of the header's version string. *)
      function LogVersion: string;

      (* What the file size implies, and what has actually been handed out.
        They differ only if the file was truncated mid-write. *)
      property ExpectedRecords: Int64 read FExpectedRecords;
      property RecordsRead: Int64 read FRecordsRead;
   end;

(* THE RECORDS ExportToADIF EMITS, and the reason this predicate is here rather
  than in each caller: logdump's JSONL and the SQLite importer must agree about
  which records are QSOs, or the corpus compares two different populations. *)
function GoodLookingQSO(const aRecord: ContestExchange): boolean;

(* TQSOTime -> unix UTC seconds.

  qtYear IS THE YEAR MINUS 2000, which a byte can hold and 2026 cannot.  Both
  writers agree (tree.pas: `UTC.wYear - 2000`; uEditQSO likewise) and so does
  logdump's own decoding.  Getting the epoch wrong moves every QSO in a log by
  a century and fails nothing, which is why it is one function with a test
  against a real fixture rather than an expression at each call site.

  A zero date -- which tree.pas writes for "no time" -- returns 0. *)
function QSOTimeToUnixUTC(const aTime: TQSOTime): Int64;

(* The inverse, for the exporter and for round-trip tests.  Years outside
  2000..2255 cannot be represented and raise: silently truncating would
  reproduce the very bug the note above describes. *)
function UnixUTCToQSOTime(aUnix: Int64): TQSOTime;

implementation

uses
   DateUtils,
   uLogNote;   (* SetNoteText -- where a note lives in the live record *)

const
   (* The epoch TR4W's on-disk byte is relative to. Named rather than repeated. *)
   QSO_TIME_YEAR_BASE = 2000;

function GoodLookingQSO(const aRecord: ContestExchange): boolean;
begin
   Result :=
      (aRecord.ceRecordKind = rkQSO)     and
      (not aRecord.ceQSO_Deleted)        and
      (aRecord.Band <> NoBand)           and
      (aRecord.Mode <> NoMode)           and
      (not aRecord.ceQSO_Deleted);
end;

function QSOTimeToUnixUTC(const aTime: TQSOTime): Int64;
var
   dt: TDateTime;
begin
   (* tree.pas writes qtYear := 0 for "no time", and a zero month or day cannot
     be encoded at all. Report it as 0 rather than as 1 January 2000, which
     would look like a real QSO in the year the log format was invented. *)
   if (aTime.qtMonth = 0) or (aTime.qtDay = 0) then
      begin
      Result := 0;
      Exit;
      end;

   dt := EncodeDate(QSO_TIME_YEAR_BASE + aTime.qtYear, aTime.qtMonth, aTime.qtDay) +
         EncodeTime(aTime.qtHour, aTime.qtMinute, aTime.qtSecond, 0);
   Result := DateTimeToUnix(dt);
end;

function UnixUTCToQSOTime(aUnix: Int64): TQSOTime;
var
   dt: TDateTime;
   y, mo, d, h, mi, s, ms: word;
begin
   FillChar(Result, SizeOf(Result), 0);
   if aUnix = 0 then
      begin
      Exit;
      end;

   dt := UnixToDateTime(aUnix);
   DecodeDate(dt, y, mo, d);
   DecodeTime(dt, h, mi, s, ms);

   if (y < QSO_TIME_YEAR_BASE) or (y > QSO_TIME_YEAR_BASE + 255) then
      begin
      raise ERangeError.CreateFmt(
         'The year %d cannot be stored in a TR4W binary log: the on-disk year ' +
         'is a single byte counted from %d, so the range is %d..%d.',
         [y, QSO_TIME_YEAR_BASE, QSO_TIME_YEAR_BASE, QSO_TIME_YEAR_BASE + 255]);
      end;

   Result.qtYear   := y - QSO_TIME_YEAR_BASE;
   Result.qtMonth  := mo;
   Result.qtDay    := d;
   Result.qtHour   := h;
   Result.qtMinute := mi;
   Result.qtSecond := s;
end;

(* --------------------------------------------------------------------------- *)

function TrwNoteText(const aTrw: TTrwRecordV17): AnsiString;
var
   region : array[0..TRW_NOTE_REGION - 1] of AnsiChar;
   n      : integer;
   i      : integer;
begin
   (* The region is wider than Prefix: that is the D7 encoding of a note (see
     uLogNote). It lies wholly inside the frozen record -- Prefix is at 36, so
     36..115 -- which uTestLogBinaryFile pins. *)
   Move(aTrw.Prefix, region, SizeOf(region));

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

procedure TrwRecordToQso(const aTrw: TTrwRecordV17; var aQso: ContestExchange);
var
   i: integer;
begin
   aQso.Clear;

   aQso.tSysTime.qtYear   := aTrw.tSysTime.qtYear;
   aQso.tSysTime.qtMonth  := aTrw.tSysTime.qtMonth;
   aQso.tSysTime.qtDay    := aTrw.tSysTime.qtDay;
   aQso.tSysTime.qtHour   := aTrw.tSysTime.qtHour;
   aQso.tSysTime.qtMinute := aTrw.tSysTime.qtMinute;
   aQso.tSysTime.qtSecond := aTrw.tSysTime.qtSecond;
   aQso.Band := BandType(aTrw.Band);
   aQso.Mode := ModeType(aTrw.Mode);
   aQso.ceQSOID1 := aTrw.ceQSOID1;
   aQso.ceQSOID2 := aTrw.ceQSOID2;
   aQso.Frequency := aTrw.Frequency;

   (* THE LEGACY DELETE FLAG IS FOLDED HERE, AT THE ONE DOOR OLD RECORDS COME
     THROUGH. A .TRW written before 2026-09-02 carries ceQSO_Skiped -- Alt-Y set
     it -- and nothing downstream reads that field any more. The importer writes
     is_skipped as False, so without the fold the deletion would be lost on the
     way in and the QSO would come back scored and exported.

     MEASURED, NOT REASONED: without it the golden corpus went from 24 passed
     to 16 passed / 8 FAILED -- eight logs whose deleted QSOs reappeared in the
     Cabrillo. See ceQSO_Skiped in VC.pas. *)
   aQso.ceQSO_Deleted := aTrw.ceQSO_Deleted or aTrw.ceQSO_Skiped;
   aQso.ceQSO_Skiped := False;

   aQso.ceComputerID := aTrw.ceComputerID;
   aQso.ceOperatorID := aTrw.ceOperatorID;
   aQso.ceRecordKind := LogRecordKind(aTrw.ceRecordKind);
   aQso.ceSendToServer := aTrw.ceSendToServer;
   aQso.ceNeedSendToServerAE := aTrw.ceNeedSendToServerAE;
   aQso.ceDupe := aTrw.ceDupe;
   aQso.PostalCode_old := aTrw.PostalCode_old;
   aQso.ZERO_01 := aTrw.ZERO_01;
   aQso.Prefix := aTrw.Prefix;
   aQso.ZERO_02 := aTrw.ZERO_02;
   aQso.Callsign := aTrw.Callsign;
   aQso.Age := aTrw.Age;
   aQso.ceWasSendInQTC := aTrw.ceWasSendInQTC;
   aQso.DomesticMult := aTrw.DomesticMult;
   aQso.DXMult := aTrw.DXMult;
   aQso.PrefixMult := aTrw.PrefixMult;
   aQso.ZoneMult := aTrw.ZoneMult;
   aQso.ExtMode := ExtendedModeType(aTrw.ExtMode);
   aQso.ExchString := aTrw.ExchString;
   aQso.ceClass := aTrw.ceClass;
   aQso.ZERO_04 := aTrw.ZERO_04;
   aQso.Precedence := aTrw.Precedence;
   aQso.ceRadio := RadioType(aTrw.ceRadio);
   aQso.Check := aTrw.Check;

   aQso.QTH.CountryID := aTrw.QTH.CountryID;
   aQso.QTH.Zone := aTrw.QTH.Zone;
   aQso.QTH.reserved := aTrw.QTH.reserved;
   aQso.QTH.Prefix := aTrw.QTH.Prefix;
   aQso.QTH.Continent := ContinentType(aTrw.QTH.Continent);
   aQso.QTH.StandardCall := aTrw.QTH.StandardCall;
   aQso.QTH.Country := aTrw.QTH.Country;

   aQso.DXQTH := aTrw.DXQTH;
   aQso.ZERO_05 := aTrw.ZERO_05;
   aQso.Radio := InterfacedRadioType(aTrw.Radio);
   aQso.DomMultQTH := aTrw.DomMultQTH;
   aQso.ZERO_06 := aTrw.ZERO_06;
   aQso.DomesticQTH := aTrw.DomesticQTH;
   aQso.ZERO_07 := aTrw.ZERO_07;
   aQso.Name := aTrw.Name;
   aQso.ZERO_08 := aTrw.ZERO_08;
   aQso.Power := aTrw.Power;
   aQso.ZERO_09 := aTrw.ZERO_09;
   aQso.NumberReceived := aTrw.NumberReceived;
   aQso.NumberSent := aTrw.NumberSent;
   aQso.RSTSent := aTrw.RSTSent;
   aQso.RSTReceived := aTrw.RSTReceived;
   aQso.QTHString := aTrw.QTHString;
   aQso.ZERO_10 := aTrw.ZERO_10;
   aQso.RandomCharsSent := aTrw.RandomCharsSent;
   aQso.TenTenNum := aTrw.TenTenNum;
   aQso.Chapter := aTrw.Chapter;
   aQso.ZERO_11 := aTrw.ZERO_11;
   aQso.ceClearDupeSheet := aTrw.ceClearDupeSheet;
   aQso.ceSearchAndPounce := aTrw.ceSearchAndPounce;
   aQso.Prefecture := aTrw.Prefecture;
   aQso.InhibitMults := aTrw.InhibitMults;
   aQso.Zone := aTrw.Zone;
   aQso.NameSent := aTrw.NameSent;
   aQso.Kids := aTrw.Kids;
   (* A legacy contest's handle IS its legacy number (Q108 S2); the importer
     refuses a number above the legacy range. *)
   aQso.ceContest := TContestHandle.FromByte(aTrw.ceContest);
   aQso.QSOPoints := aTrw.QSOPoints;
   aQso.RandomCharsReceived := aTrw.RandomCharsReceived;
   aQso.ZERO_13 := aTrw.ZERO_13;
   aQso.ceClearMultSheet := aTrw.ceClearMultSheet;
   aQso.MP3Record := aTrw.MP3Record;
   for i := Low(aTrw.ceOperator) to High(aTrw.ceOperator) do
      begin
      aQso.ceOperator[i] := aTrw.ceOperator[i];
      end;
   aQso.id := aTrw.id;
   aQso.ceXQSO := aTrw.ceXQSO;

   (* NOT CARRIED, because no D7 file holds them (they were D7's sReserved, which
     nothing ever wrote) and Clear left them unset: RcvdYear/RcvdYearKnown (the
     importer refills the year from Zone for a year contest), YearSent/
     YearSentKnown (the importer stamps the file's STX_STRING year),
     ceOffContest (the store's one-shot stamp judges every row) and ceRoverQTH. *)

   (* A NOTE IS A BYTE REGION, NOT FIELDS: its text runs on from Prefix across
     the fields above, so the copies just made hold fragments of it. Carry the
     text itself, from the file's region into the live one. *)
   if aQso.ceRecordKind = rkNote then
      begin
      SetNoteText(aQso, TrwNoteText(aTrw));
      end;
end;

(* --------------------------------------------------------------------------- *)

procedure TLogBinaryReader.ReportFailure(aStatus: TLogBinaryStatus; const aMessage: string);
begin
   FStatus := aStatus;
   FMessage := aMessage;
   FreeAndNil(FStream);
end;

constructor TLogBinaryReader.Create(const aFileName: string);
var
   recordBytes: Int64;
   leftover: Int64;
begin
   inherited Create;
   FFileName := aFileName;
   FStatus := lbOK;
   FMessage := '';
   FRecordsRead := 0;
   FExpectedRecords := 0;
   FillChar(FHeader, SizeOf(FHeader), 0);

   try
      (* fmShareDenyNone: a multi-op station may well have TR4W holding this
        file open, and refusing to read it would be a worse answer than
        reading a snapshot of it. *)
      FStream := TFileStream.Create(AnsiString(aFileName),
                                    fmOpenRead or fmShareDenyNone);
   except
      on E: Exception do
         begin
         ReportFailure(lbCannotOpen,
              SysUtils.Format('Cannot open the log "%s": %s', [aFileName, E.Message]));
         Exit;
         end;
   end;

   if FStream.Size < SizeOf(FHeader) then
      begin
      ReportFailure(lbTooSmall,
           SysUtils.Format('"%s" is %d bytes, which is too small to hold even a log ' +
                  'header (%d bytes).', [aFileName, FStream.Size, SizeOf(FHeader)]));
      Exit;
      end;

   recordBytes := FStream.Size - SizeOf(FHeader);
   leftover := recordBytes mod SizeOf(TTrwRecordV17);

   (* THE CHECK THAT PREVENTS GARBAGE. See the unit header: a stride mismatch
     means a file whose records are not the 376-byte D7 v1.7 record, and
     reading anyway produces plausible-looking nonsense rather than a
     failure. *)
   if leftover <> 0 then
      begin
      ReportFailure(lbStrideMismatch,
           SysUtils.Format('"%s" is %d bytes, which is not a header (%d) plus a whole ' +
                  'number of %d-byte records -- %d byte(s) are left over. That ' +
                  'normally means the log was written by a version of TR4W whose ' +
                  'QSO record was a different size (a log older than v1.7, or a ' +
                  'damaged file), and reading it at this stride would produce ' +
                  'misaligned data rather than an error.',
                  [aFileName, FStream.Size, SizeOf(FHeader),
                   SizeOf(TTrwRecordV17), leftover]));
      Exit;
      end;

   FExpectedRecords := recordBytes div SizeOf(TTrwRecordV17);

   if FStream.Read(FHeader, SizeOf(FHeader)) <> SizeOf(FHeader) then
      begin
      ReportFailure(lbHeaderUnreadable,
           SysUtils.Format('The header of "%s" could not be read.', [aFileName]));
      Exit;
      end;
end;

destructor TLogBinaryReader.Destroy;
begin
   FStream.Free;
   inherited Destroy;
end;

function TLogBinaryReader.LogVersion: string;
begin
   (* The first four bytes -- 'v1.7'. The rest of the field is #0, a space and
     a CRLF, which are framing rather than version. *)
   Result := string(Copy(AnsiString(FHeader.lhVersionString), 1, 4));
end;

function TLogBinaryReader.ReadNext(out aRecord: ContestExchange): boolean;
var
   got: longint;
   trw: TTrwRecordV17;
begin
   aRecord.Clear;
   Result := False;

   if FStream = nil then
      begin
      Exit;
      end;

   (* THE FILE'S RECORD, NOT THE PROGRAM'S: read into the frozen D7 type and
     carried across field by field (TrwRecordToQso), which also folds the
     legacy delete flag and leaves every 5.x field unset. *)
   got := FStream.Read(trw, SizeOf(trw));

   (* A SHORT READ IS END OF FILE, NOT AN ERROR -- and it is not reported,
     because the legacy reader does not report it either and the corpus
     compares our record count against what ExportToADIF saw. See the unit
     header. *)
   if got <> SizeOf(trw) then
      begin
      Exit;
      end;

   TrwRecordToQso(trw, aRecord);

   Inc(FRecordsRead);
   Result := True;
end;

end.

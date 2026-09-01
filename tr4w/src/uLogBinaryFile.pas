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

{ READING A BINARY TR4W LOG -- THE ONE PLACE THAT KNOWS THE ON-DISK LAYOUT.

  Extracted from test\logdump\logdump.lpr on 2026-09-01, BEFORE the SQLite
  importer became its second copy rather than after.  CLAUDE.md: "when you add
  the second caller of something private to a unit, that is the moment to lift
  it out, not later" -- and this reader carries two pieces of knowledge that
  were learned the hard way and would not have survived being re-derived:

  1. A LOG IS header + N * record, EXACTLY.  If the file size does not divide,
     it was written by a TR4W whose SizeOfContestExchange differed -- a field
     added or removed since -- and reading at the current stride yields
     MISALIGNED GARBAGE rather than an error.  Refuse instead.

  2. A SHORT READ AT THE TAIL IS END-OF-FILE, SILENTLY.  That is what the
     legacy ReadLogFile does (MainUnit): it reads SizeOf(ContestExchange) and
     treats "fewer bytes than that" as the end.  Anything stricter reports
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
  no purity gain today; there is a portability gain the day VC is split. }
unit uLogBinaryFile;

{$I tr4w.inc}

interface

uses
   Classes, SysUtils, VC;

type
   TLogBinaryStatus = (
      lbOK,
      lbCannotOpen,        { no such file, or locked by a running TR4W }
      lbTooSmall,          { smaller than one header }
      lbStrideMismatch,    { not header + N * record -- see the header comment }
      lbHeaderUnreadable
   );

   { Reads a .trw / .dat sequentially.  One instance per file, forward only --
     which is all the importer and logdump need, and it keeps the short-read
     rule in one place instead of at every seek. }
   TLogBinaryReader = class(TObject)
   private
      FStream: TFileStream;
      FFileName: string;
      FStatus: TLogBinaryStatus;
      FMessage: string;
      FHeader: TLogHeader;
      FExpectedRecords: Int64;
      FRecordsRead: Int64;

      procedure ReportFailure(aStatus: TLogBinaryStatus; const aMessage: string);
   public
      { Opens and validates in one step.  Check Status before reading; a reader
        that failed to open returns False from ReadNext and says why. }
      constructor Create(const aFileName: string);
      destructor Destroy; override;

      { False at end of file, and False if the reader never opened.  A short
        read at the tail is end of file, not an error -- see the unit header. }
      function ReadNext(out aRecord: ContestExchange): boolean;

      property Status: TLogBinaryStatus read FStatus;
      { Empty when Status is lbOK. Otherwise a sentence for a human. }
      property Message: string read FMessage;
      property FileName: string read FFileName;
      property Header: TLogHeader read FHeader;

      { 'v1.7' -- the first four bytes of the header's version string. }
      function LogVersion: string;

      { What the file size implies, and what has actually been handed out.
        They differ only if the file was truncated mid-write. }
      property ExpectedRecords: Int64 read FExpectedRecords;
      property RecordsRead: Int64 read FRecordsRead;
   end;

{ THE RECORDS ExportToADIF EMITS, and the reason this predicate is here rather
  than in each caller: logdump's JSONL and the SQLite importer must agree about
  which records are QSOs, or the corpus compares two different populations. }
function GoodLookingQSO(const aRecord: ContestExchange): boolean;

{ TQSOTime -> unix UTC seconds.

  qtYear IS THE YEAR MINUS 2000, which a byte can hold and 2026 cannot.  Both
  writers agree (tree.pas: `UTC.wYear - 2000`; uEditQSO likewise) and so does
  logdump's own decoding.  Getting the epoch wrong moves every QSO in a log by
  a century and fails nothing, which is why it is one function with a test
  against a real fixture rather than an expression at each call site.

  A zero date -- which tree.pas writes for "no time" -- returns 0. }
function QSOTimeToUnixUTC(const aTime: TQSOTime): Int64;

{ The inverse, for the exporter and for round-trip tests.  Years outside
  2000..2255 cannot be represented and raise: silently truncating would
  reproduce the very bug the note above describes. }
function UnixUTCToQSOTime(aUnix: Int64): TQSOTime;

implementation

uses
   DateUtils;

const
   { The epoch TR4W's on-disk byte is relative to. Named rather than repeated. }
   QSO_TIME_YEAR_BASE = 2000;

function GoodLookingQSO(const aRecord: ContestExchange): boolean;
begin
   Result :=
      (aRecord.ceRecordKind = rkQSO)     and
      (not aRecord.ceQSO_Skiped)         and
      (aRecord.Band <> NoBand)           and
      (aRecord.Mode <> NoMode)           and
      (not aRecord.ceQSO_Deleted);
end;

function QSOTimeToUnixUTC(const aTime: TQSOTime): Int64;
var
   dt: TDateTime;
begin
   { tree.pas writes qtYear := 0 for "no time", and a zero month or day cannot
     be encoded at all. Report it as 0 rather than as 1 January 2000, which
     would look like a real QSO in the year the log format was invented. }
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

{ --------------------------------------------------------------------------- }

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
      { fmShareDenyNone: a multi-op station may well have TR4W holding this
        file open, and refusing to read it would be a worse answer than
        reading a snapshot of it. }
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
   leftover := recordBytes mod SizeOf(ContestExchange);

   { THE CHECK THAT PREVENTS GARBAGE. See the unit header: a stride mismatch
     means a different SizeOfContestExchange, and reading anyway produces
     plausible-looking nonsense rather than a failure. }
   if leftover <> 0 then
      begin
      ReportFailure(lbStrideMismatch,
           SysUtils.Format('"%s" is %d bytes, which is not a header (%d) plus a whole ' +
                  'number of %d-byte records -- %d byte(s) are left over. That ' +
                  'normally means the log was written by a version of TR4W whose ' +
                  'QSO record was a different size, and reading it at this ' +
                  'stride would produce misaligned data rather than an error. ' +
                  'Open the log in a current TR4W and save it to upgrade it in ' +
                  'place, then import again.',
                  [aFileName, FStream.Size, SizeOf(FHeader),
                   SizeOf(ContestExchange), leftover]));
      Exit;
      end;

   FExpectedRecords := recordBytes div SizeOf(ContestExchange);

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
   { The first four bytes -- 'v1.7'. The rest of the field is #0, a space and
     a CRLF, which are framing rather than version. }
   Result := string(Copy(AnsiString(FHeader.lhVersionString), 1, 4));
end;

function TLogBinaryReader.ReadNext(out aRecord: ContestExchange): boolean;
var
   got: longint;
begin
   FillChar(aRecord, SizeOf(aRecord), 0);
   Result := False;

   if FStream = nil then
      begin
      Exit;
      end;

   got := FStream.Read(aRecord, SizeOf(aRecord));

   { A SHORT READ IS END OF FILE, NOT AN ERROR -- and it is not reported,
     because the legacy reader does not report it either and the corpus
     compares our record count against what ExportToADIF saw. See the unit
     header. }
   if got <> SizeOf(aRecord) then
      begin
      Exit;
      end;

   Inc(FRecordsRead);
   Result := True;
end;

end.

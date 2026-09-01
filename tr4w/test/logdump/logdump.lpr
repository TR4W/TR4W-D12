program logdump;

{
  TR4W Binary Log Dumper

  Usage:
    logdump.exe <path-to-log.dat>           writes JSONL to stdout
    logdump.exe <path-to-log.dat> <out.jsonl>  writes JSONL to file

  Reads a TR4W binary log file (.dat) and writes one JSON object per line,
  using the canonical ContestExchange record definition from VC.pas.

  Filter: emits all records that pass the GoodLookingQSO check
    (ceRecordKind=rkQSO, not deleted, not skipped, Band<>NoBand, Mode<>NoMode).
  Other records are skipped silently -- matches what ExportToADIF emits.

  Used by tr4w/test/python/verify_adif_export.py to cross-check ADIF export
  against the canonical binary log without re-implementing the on-disk
  layout in Python (which would drift the moment ContestExchange changes).

  Exit codes:
    0  success
    1  bad arguments
    2  file open failed
    3  read error
    4  output file open failed
}

{$APPTYPE CONSOLE}

uses
   Windows,
   SysUtils,
   VC in '..\..\src\VC.pas',
   uLogBinaryFile in '..\..\src\uLogBinaryFile.pas';

var
   gOutHandle : THandle = 0;
   gOutToFile : Boolean = False;

// --- output helpers -----------------------------------------------------

procedure WriteOut(const s: string);
var
   bytesWritten : DWORD;
begin
   if gOutToFile then
      Windows.WriteFile(gOutHandle, PChar(s)^, Length(s), bytesWritten, nil)
   else
      Write(s);
end;

procedure WriteLnOut(const s: string);
begin
   WriteOut(s + #13#10);
end;

// --- JSON escape --------------------------------------------------------

function JsonEscape(const s: string): string;
var
   i  : Integer;
   ch : Char;
begin
   Result := '';
   for i := 1 to Length(s) do
      begin
      ch := s[i];
      case ch of
         '"'  : Result := Result + '\"';
         '\'  : Result := Result + '\\';
         #8   : Result := Result + '\b';
         #9   : Result := Result + '\t';
         #10  : Result := Result + '\n';
         #12  : Result := Result + '\f';
         #13  : Result := Result + '\r';
      else
         if Ord(ch) < 32 then
            Result := Result + SysUtils.Format('\u%.4x', [Ord(ch)])
         else
            Result := Result + ch;
         end;
      end;
end;

// --- enum / lookup helpers ---------------------------------------------

function BandToString(b: BandType): string;
begin
   Result := string(ADIFBANDSTRINGSARRAY[b]);
end;

function ModeToString(m: ModeType): string;
begin
   Result := string(ADIFModeString[m]);
end;

function ExtModeToString(m: ExtendedModeType): string;
begin
   Result := ExtendedModeStringArray[m];
end;

function ContestToString(c: ContestType): string;
begin
   // Use the ADIF contest name when set; otherwise fall back to the
   // enum ordinal.
   if ContestsArray[c].ADIFName <> '' then
      Result := string(ContestsArray[c].ADIFName)
   else
      Result := 'CONTEST_' + IntToStr(Ord(c));
end;

function RecordKindToString(k: LogRecordKind): string;
begin
   case k of
      rkQSO  : Result := 'rkQSO';
      rkQTCR : Result := 'rkQTCR';
      rkQTCS : Result := 'rkQTCS';
      rkNote : Result := 'rkNote';
   else
      Result := 'rkUnknown';
   end;
end;

// --- record emission ----------------------------------------------------

procedure EmitField(var first: Boolean; const name: string; const value: string);
begin
   if not first then
      WriteOut(',');
   first := False;
   WriteOut('"' + name + '":"' + JsonEscape(value) + '"');
end;

procedure EmitIntField(var first: Boolean; const name: string; value: Integer);
begin
   if not first then
      WriteOut(',');
   first := False;
   WriteOut('"' + name + '":' + IntToStr(value));
end;

procedure EmitBoolField(var first: Boolean; const name: string; value: Boolean);
begin
   if not first then
      WriteOut(',');
   first := False;
   if value then
      WriteOut('"' + name + '":true')
   else
      WriteOut('"' + name + '":false');
end;

procedure EmitRecord(const rec: ContestExchange);
var
   first : Boolean;
begin
   first := True;
   WriteOut('{');
   // Identification
   EmitField(first,    'Call',         string(rec.Callsign));
   EmitField(first,    'Band',         BandToString(rec.Band));
   EmitField(first,    'Mode',         ModeToString(rec.Mode));
   EmitField(first,    'ExtMode',      ExtModeToString(rec.ExtMode));
   EmitIntField(first, 'FrequencyHz',  rec.Frequency);
   EmitField(first,    'Contest',      ContestToString(rec.ceContest));

   // Time -- format as yyyymmdd / hhmmss to match ADIF directly
   EmitField(first,    'QSODate',
      SysUtils.Format('%.4d%.2d%.2d',
         [rec.tSysTime.qtYear + 2000,
          rec.tSysTime.qtMonth,
          rec.tSysTime.qtDay]));
   EmitField(first,    'QSOTime',
      SysUtils.Format('%.2d%.2d%.2d',
         [rec.tSysTime.qtHour,
          rec.tSysTime.qtMinute,
          rec.tSysTime.qtSecond]));

   // RST + serials
   EmitIntField(first, 'RSTSent',         rec.RSTSent);
   EmitIntField(first, 'RSTReceived',     rec.RSTReceived);
   EmitIntField(first, 'NumberSent',      rec.NumberSent);
   EmitIntField(first, 'NumberReceived',  rec.NumberReceived);

   // Exchange / location
   EmitField(first,    'ExchString',   string(rec.ExchString));
   EmitField(first,    'QTHString',    string(rec.QTHString));
   EmitField(first,    'DomesticQTH',  string(rec.DomesticQTH));
   EmitField(first,    'Name',         string(rec.Name));
   EmitField(first,    'Power',        string(rec.Power));
   EmitIntField(first, 'Check',        rec.Check);
   EmitField(first,    'Class',        string(rec.ceClass));
   EmitIntField(first, 'Age',          rec.Age);
   EmitIntField(first, 'TenTenNum',    rec.TenTenNum);
   EmitIntField(first, 'Zone',         rec.Zone);

   if rec.Precedence = #0 then
      EmitField(first, 'Precedence', '')
   else
      EmitField(first, 'Precedence', string(rec.Precedence));

   // QTH sub-record (the resolved-from-callsign location)
   EmitField(first, 'CountryID', string(rec.QTH.CountryID));
   EmitField(first, 'Prefix',    string(rec.QTH.Prefix));

   // Operator + log GUID
   EmitField(first,    'Operator',     string(rec.ceOperator));
   EmitField(first,    'ID',           string(rec.id));

   // Contest-attribute flag the verifier needs.  CountyLineAllowed is
   // True for the 13 single-state QSO parties where a CALL/<county>
   // form decomposes into bare CALL + APP_TR4W_ROVERCALL.  Living in
   // ContestsArray (Pascal), we surface it so Python doesn't have to
   // duplicate the list.
   EmitBoolField(first, 'CountyLineAllowed',
                 ContestsArray[rec.ceContest].CountyLineAllowed);

   // Filter-relevant flags (Python can re-apply the GoodLookingQSO
   // filter if needed)
   EmitField(first,    'RecordKind',   RecordKindToString(rec.ceRecordKind));
   EmitBoolField(first,'Deleted',      rec.ceQSO_Deleted);
   EmitBoolField(first,'Skipped',      rec.ceQSO_Skiped);

   WriteOut('}'#13#10);
end;

// --- main loop ----------------------------------------------------------

// THE READING LIVES IN src\uLogBinaryFile.pas (2026-09-01).
//
// It used to live here: an up-front "header + N * record" divisibility check,
// a Windows.ReadFile loop, and the rule that a SHORT READ AT THE TAIL IS
// END-OF-FILE because that is what the legacy ReadLogFile does.  All of that is
// hard-won and none of it is about dumping JSON.
//
// It moved when the SQLite importer needed the same reader -- BEFORE becoming
// its second copy rather than after, per CLAUDE.md.  Two copies of the
// short-read rule would drift, and the drift would be invisible in the worst
// way available here: the JSONL and the importer would disagree about how many
// records a log contains, and the corpus would be comparing two different
// populations while reporting green.
//
// GoodLookingQSO moved with it for the same reason -- it decides which records
// ExportToADIF emits, and this program exists to be compared against that.

procedure DumpLog(const logPath: string);
var
   reader       : TLogBinaryReader;
   rec          : ContestExchange;
   recCount     : Integer;
   goodCount    : Integer;
   skippedCount : Integer;
begin
   reader := TLogBinaryReader.Create(logPath);
   try
      if reader.Status <> lbOK then
         begin
         Writeln(ErrOutput, 'logdump: ', reader.Message);
         // Preserved from the hand-rolled version: 2 could not open, 3 could
         // not be read as a log.  verify_adif_export.py distinguishes them.
         if reader.Status = lbCannotOpen then
            Halt(2)
         else
            Halt(3);
         end;

      WriteLnOut('{"_meta":true,"logVersion":"' +
                 JsonEscape(reader.LogVersion) + '","recordSize":' +
                 IntToStr(SizeOfContestExchange) + '}');

      recCount     := 0;
      goodCount    := 0;
      skippedCount := 0;

      while reader.ReadNext(rec) do
         begin
         Inc(recCount);
         if GoodLookingQSO(rec) then
            begin
            EmitRecord(rec);
            Inc(goodCount);
            end
         else
            Inc(skippedCount);
         end;

      // The reader treats a short read at the tail as end-of-file and says
      // nothing, matching TR4W.  The counts are how that becomes visible
      // without changing the rule: they can only differ if the file shrank
      // between the size check and the read.
      if recCount <> reader.ExpectedRecords then
         begin
         Writeln(ErrOutput,
                 'logdump: WARNING -- the file size implies ',
                 reader.ExpectedRecords, ' record(s) but ', recCount,
                 ' were read.  A trailing partial record is dropped silently, ',
                 'matching TR4W behaviour.');
         end;

      Writeln(ErrOutput, 'logdump: ', recCount, ' total records, ',
              goodCount, ' good (emitted), ', skippedCount, ' skipped');
   finally
      reader.Free;
   end;
end;

// --- entry point --------------------------------------------------------

begin
   if (ParamCount < 1) or (ParamCount > 2) then
      begin
      Writeln(ErrOutput, 'Usage: logdump <log.dat> [out.jsonl]');
      Halt(1);
      end;

   if ParamCount = 2 then
      begin
      gOutHandle := CreateFile(PChar(ParamStr(2)),
                               GENERIC_WRITE,
                               FILE_SHARE_READ,
                               nil, CREATE_ALWAYS,
                               FILE_ATTRIBUTE_NORMAL, 0);
      if gOutHandle = INVALID_HANDLE_VALUE then
         begin
         Writeln(ErrOutput, 'logdump: cannot create output file ',
                 ParamStr(2));
         Halt(4);
         end;
      gOutToFile := True;
      end;

   try
      DumpLog(ParamStr(1));
   finally
      if gOutToFile then
         CloseHandle(gOutHandle);
   end;
end.

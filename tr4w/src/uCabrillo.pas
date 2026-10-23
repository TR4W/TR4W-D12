unit uCabrillo;
{$I tr4w.inc}

{
  Cabrillo line builders for use outside the final-log writer.

  WHY THIS UNIT EXISTS
  --------------------
  Several consumers need to render a single QSO as a Cabrillo "QSO:" /
  "X-QSO:" line without going through the full final-log writer in
  trdos/PostUnit.tGenerateLogPortionOfCabrilloFile (which is 1,200+
  lines of inline asm tightly coupled to its own globals).

  Currently the only consumer is the RTC 3.0 protocol's
  <CabrilloString> field (issue #920), where each contactinfo /
  contactdelete payload carries the QSO as a Cabrillo line.  Future
  consumers (header builder, score-row formatter, contest-specific
  mode/band normalization) live here too rather than fragmenting the
  source tree into one-purpose files.

  Pre-migration test target -- see docs/tr4w-migration-strategy.md
  ("Tier 1 Extraction Pattern").  The single-QSO builder here uses:

    uCabrilloFormat    -- FormatCabrilloFreq
    uContestRegistry   -- the QSO's contest's CabrilloModeString (Q54)
    uExchangeBuilder   -- BuildSentExchangeText / BuildRxExchangeText

  ...which are the same pure helpers postunit.pas now imports, so the
  Cabrillo lines this unit produces agree with the final-log writer
  on freq, mode, and exchange shape.

  What we DO NOT promise: byte-identical column alignment with the
  final-log writer.  The Cabrillo spec only requires whitespace
  separation between fields; parsers (HAMSCORE, COS, log checkers)
  tokenize.  Operators submitting their log through the official
  Cabrillo file path are unaffected.
}

interface

uses
   VC,
   uQsoMyFacts;   (* TQsoMyFacts -- a stored QSO's own station *)

// ---------------------------------------------------------------------------
// BuildSingleQsoCabrilloLine
//
// Returns a single Cabrillo "QSO:" or "X-QSO:" line for the given QSO,
// terminated with no line break (caller adds CRLF or wraps in XML).
//
// Format (whitespace-separated, per Cabrillo spec):
//   QSO: <freq> <mode> <date> <time> <mycall> <sent-exch> <hiscall> <rcv-exch>
//
// X-QSO records (RXData.ceXQSO = True) get an "X-QSO: " prefix instead of
// "QSO: " per Issue #750 / Cabrillo spec.
// ---------------------------------------------------------------------------
function BuildSingleQsoCabrilloLine(const RXData: ContestExchange): AnsiString; overload;

(* THE SAME LINE FOR A QSO THAT IS ALREADY IN THE LOG (issue 95; NY4I's ruling
   Q13: a logged QSO reads its record, never live state).

   Edit QSO and the Tools -> HamScore resync re-emit a STORED QSO, possibly
   days after it was logged and after MY CALL, the grid or the CQ exchange
   changed. The line then says what the record says, by the same routines the
   final Cabrillo writer asks:

     our call       uLogSource.ExportCallFor(aFacts) -- the row's my_call, else
                    the log's declared call, else today's MY CALL
     sent exchange  rebuilt from the QSO's own fields (an edited serial shows)
                    and the row's recorded grid -- uExchangeBuilder.
                    BuildSentExchangeTextOf; aRecordedSent (exchange_sent) is
                    used verbatim only for an imported row

   aFacts / aRecordedSent are what the log read beside the QSO
   (LogSourceNext, LogSourceReadStationAtIndex). The one-argument overload is
   the QSO for which the session IS the record: a row that never captured its
   station (NotCapturedMyFacts, ruling A) -- and the test harness. *)
function BuildSingleQsoCabrilloLine(const RXData: ContestExchange;
                                    const aFacts: TQsoMyFacts;
                                    const aRecordedSent: AnsiString): AnsiString; overload;

implementation

uses
   uLogSource,      // ExportCallFor -- the export's own answer for our call
   SysUtils,
   uCabrilloFormat,        // FormatCabrilloFreq
   uContestRegistry,       // ContestIdentity -- the QSO's contest's mode column
   uExchangeBuilder,      // BuildSentExchangeText / BuildRxExchangeText
   LogWind;                // the contest globals this renders from

function BuildSingleQsoCabrilloLine(const RXData: ContestExchange): AnsiString;
begin
   Result := BuildSingleQsoCabrilloLine(RXData, NotCapturedMyFacts, '');
end;

function BuildSingleQsoCabrilloLine(const RXData: ContestExchange;
                                    const aFacts: TQsoMyFacts;
                                    const aRecordedSent: AnsiString): AnsiString;
var
   sFreq:     AnsiString;
   sMode:     AnsiString;
   sPrefix:   AnsiString;
   sentExch:  string;
   rcvExch:   string;
   begin
   sFreq := FormatCabrilloFreq(RXData.Band, RXData.Frequency, True);
   (* THE MODE COLUMN IS THE QSO'S CONTEST'S (Q54, NY4I 2026-10-16) -- the
      same CabrilloModeString PostUnit's Cabrillo file asks, so HamScore's
      line and the submitted file cannot spell a mode differently. It was
      FormatCabrilloMode with no override, which agreed with the file only
      while no contest overrode the mode column. The QSO's own contest,
      as uExchangeBuilder asks for the exchanges below. *)
   sMode := AnsiString(ContestIdentity(RXData.ceContest).CabrilloModeString(
               RXData.Mode, RXData.ExtMode));

   sentExch := BuildSentExchangeTextOf(RXData, aFacts, aRecordedSent);
   rcvExch  := BuildRxExchangeText(RXData);

   if LoggedQSOIsXQSO(RXData) then
      begin
      sPrefix := 'X-QSO: '
      end
   else
      begin
      sPrefix := 'QSO: ';
      end;

   // YYYY-MM-DD HHMM per Cabrillo spec (time is 4 digits, no colon).
   Result := AnsiString(Format(
      '%s%s %s 20%.2d-%.2d-%.2d %.2d%.2d %s %s %s %s',
      [string(sPrefix),
       string(sFreq),
       string(sMode),
       RXData.tSysTime.qtYear, RXData.tSysTime.qtMonth, RXData.tSysTime.qtDay,
       RXData.tSysTime.qtHour, RXData.tSysTime.qtMinute,
       ExportCallFor(aFacts),
       sentExch,
       string(RXData.Callsign),
       rcvExch]));
   end;

end.

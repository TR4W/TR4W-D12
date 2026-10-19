unit uADIF;
{$I tr4w.inc}

{
  TR4W ADIF lexer + helpers — focused, dependency-light, testable.

  This unit contains the migration-touchy core of ADIF import: the
  string-slicing lexer and the small helpers that map ADIF field text
  into TR4W types (band, mode, date, time, contest).

  It deliberately depends only on SysUtils / StrUtils / Log4D / VC so
  the unit-test runner can link it without pulling MainUnit and its
  window / contest-state globals.

  Issue #887 — second incremental commit.  This commit adds:
    - TADIF_Fields enum (moved from MainUnit)
    - GetADIFBand / GetADIFMode / GetADIFSubMode (moved)
    - ADIFDateStringToQSOTime / ADIFTimeStringToQSOTime (moved)
    - GetContestByADIFName (moved; cache preserved as unit-private)
    - IsValidGUID (local copy; avoids dragging trdos/logstuff.pas)

  Previously shipped (first incremental commit):
    - ParseADIFFieldsList (the lexer)
    - TADIFField / TADIFFieldList types

  Moved since (M5a, 2026-10-01): the contest-specific post-processing tail is
  the contest's own -- TContestBase.ApplyADIFImport, asked by
  ApplyADIFContestImport after the whole record is read. This unit names no
  contest on the way in; TADIFRecordTemps (what it captures for the contest)
  lives in uContestBase and is aliased below.

  See docs/tr4w-migration-strategy.md.  ADIF string handling is the
  highest-risk surface for Phase 2 (Unicode correctness); each function
  here is reachable from the unit-test runner without MainUnit baggage.

  Delphi 12 migration note:
    Bare `string` is used here.  In D7 this is AnsiString; in D12 it
    becomes UnicodeString.  ADIF is fundamentally a text format with
    UTF-8 in NAME/QTH/COMMENT fields, so the UnicodeString transition
    is the correct semantic.  Wire-byte data (CI-V, etc.) elsewhere in
    TR4W explicitly types AnsiString.
}

interface

uses
   SysUtils,
   StrUtils,
   Log4D,
   VC,
   (* TADIFRecordTemps and TADIFImportSession, the two records the generic
      importer hands to a contest -- see below. *)
   uContestBase,
   utils_text,
   (* TQsoMyFacts -- our station for one QSO, the row's my_* columns (log
      schema 3): what an import reads from the MY_* tags and an export
      writes back. A leaf; it declares nothing the units above do. *)
   uQsoMyFacts;

type
   TADIFField = record
      Name  : string;
      Value : string;
   end;

   TADIFFieldList = array of TADIFField;

   (* The raw values of every ADIF tag whose MEANING depends on the contest,
     captured by ApplyADIFFieldsToExchange for the contest to interpret once
     the whole record is read. The record is the contest model's -- it is the
     argument of TContestBase.ApplyADIFImport -- and lives in uContestBase;
     these aliases keep its old home's name working. *)
   TADIFRecordTemps = uContestBase.TADIFRecordTemps;
   TADIFImportSession = uContestBase.TADIFImportSession;

   TContestExchangeArray = array of ContestExchange;

   // ADIF field-name dispatch enum.  Order MUST match ADIF_FIELD_NAMES (the
   // lookup array in the implementation).  Adding entries requires updating
   // both.
   TADIF_Fields = (tAdifARRL_SECT = 0, tAdifBAND, tAdifCALL, tAdifCHECK,
      tAdifCLASS, tAdifCQ_Z,
      tAdifCONTEST_ID, tAdifCNTY, tadifFOC_NUM, tAdifGRIDSQUARE, tAdifFREQ,
      tAdifFREQ_RX,
      tAdifIOTA, tAdifITUZ, tAdifMODE, tAdifNAME, tAdifOPERATOR, tAdifPRECEDENCE,
      tAdifQSO_DATE, tAdifQSO_DATE_OFF, tAdifTIME_ON, tAdifTIME_OFF,
      tAdifRST_RCVD, tAdifRST_SENT, tAdifRX_PWR, tAdifSRX, tAdifSRX_STRING,
      tAdifSTATE, tAdifSTX, tAdifSTX_STRING, tAdifSUBMODE, tAdifTEN_TEN,
      tAdifVE_PROV, tAdifAPP_TR4W_HQ, tAdifAPP_N1MM_HQ, tAdifSTATION_CALLSIGN,
      tAdifQTH, tAdifPROGRAMID, tAdifAPP_N1MM_EXCHANGE1, tAdifAPP_N1MM_ID,
      tAdifAPP_TR4W_ID, tAdifSIG, tAdifSIG_INFO, tAdifPOTAREF,
      tAdifAPP_TR4W_ROVERCALL,
      // X-QSO / "not claimed" markers -- Issue #750.  Three different
      // conventions in the wild, all recognized on import:
      //   APP_TR4W_CLAIMEDQSO  value '1' = normal, '0' = X-QSO  (TR4W)
      //   APP_N1MM_CLAIMEDQSO  value '1' = normal, '0' = X-QSO  (N1MM)
      //   APP_DXLOG_XQSO       value 'Y' = X-QSO                (DXLog.net)
      // Export emits only APP_TR4W_CLAIMEDQSO; the others are import-only.
      tAdifAPP_TR4W_CLAIMEDQSO, tAdifAPP_N1MM_CLAIMEDQSO,
      tAdifAPP_DXLOG_XQSO,
      // The WAG DOK, written by that contest's exporter (M5a).
      tAdifDOK,
      // OUR STATION, AS THE RECORD STATES IT -- log schema 3, stage 2. Into
      // the row's my_* columns (MyFactsFromADIF), never today's settings.
      tAdifMY_GRIDSQUARE, tAdifMY_STATE, tAdifMY_CNTY, tAdifMY_ARRL_SECT,
      tAdifMY_SIG, tAdifMY_SIG_INFO, tAdifMY_POTA_REF, tAdifMY_IOTA,
      tAdifMY_DXCC, tAdifMY_CQ_ZONE, tAdifMY_ITU_ZONE);

// =========================================================================
// Lexer
// =========================================================================

// Parse a single ADIF record's field list from `s`.
//
// The lexer reads fields of the form `<NAME:n>VALUE` (optionally
// `<NAME:n:T>` where T is the ADIF data-type indicator — type is
// discarded).  Whitespace and free-form text between fields is ignored.
// The lexer stops at the first `<EOR>` or `<EOH>` it encounters
// (case-insensitive).
//
// Returns True if a terminator (<EOR> or <EOH>) was found.  Returns False
// when the end of `s` is reached without a terminator OR when a malformed
// tag is encountered.  Even on False, `fields` contains the fields that
// were successfully parsed before the error/end.
function ParseADIFFieldsList(const s: string;
                             out fields: TADIFFieldList): Boolean;

// =========================================================================
// Per-field type-conversion helpers
// =========================================================================

// Convert an ADIF BAND string ("20m", "70cm") to a TR4W BandType.
// Returns NoBand for unrecognized input.  Case-insensitive.
function GetADIFBand(sBand: string): BandType;

// Convert an ADIF MODE string ("CW", "SSB", "FT8", ...) to a TR4W
// (Mode, ExtendedMode) pair.  Returns NoMode for unrecognized input.
// Case-insensitive.
function GetADIFMode(sMode: string): ModeAndExtendedModeType;

// Convert an ADIF SUBMODE string ("FT4", "USB", "LSB", ...) to a TR4W
// (Mode, ExtendedMode) pair.  Returns NoMode for unrecognized input.
// Case-insensitive.
function GetADIFSubMode(sSubMode: string): ModeAndExtendedModeType;

// Parse an ADIF QSO_DATE string ("YYYYMMDD", 8 chars).  Returns True on
// success and sets qsoTime.qtYear/qtMonth/qtDay.  Returns False (without
// modifying qsoTime) on invalid input.
function ADIFDateStringToQSOTime(sDate: string;
                                 var qsoTime: TQSOTime): Boolean;

// Parse an ADIF TIME_ON / TIME_OFF string ("HHMM" or "HHMMSS").  Returns
// True on success and sets qsoTime.qtHour/qtMinute/qtSecond (seconds = 0
// when only HHMM provided).  Returns False on invalid input.
function ADIFTimeStringToQSOTime(sTime: string;
                                 var qsoTime: TQSOTime): Boolean;

(* LOOK UP A CONTEST BY ITS ADIF CONTEST_ID. True, with aContest set, when a
  contest answers to it -- by its current id or by one it was exported under
  before a rename; False otherwise, INCLUDING for an empty or all-blank value.
  The rule itself is uContestRegistry.FindContestByADIFContestId; this adds a
  single-entry cache for the common case of every QSO in a file sharing one
  contest.

  IT RETURNS WHETHER IT FOUND ONE. It used to return a contest always and
  leave the caller to compare that row's ADIFName with the input, which
  cannot recognise a former id -- and which accepted an EMPTY input as
  "found", landing on the first contest whose ADIFName was blank. *)
function GetContestByADIFName(const sADIFName: string;
                              out aContest: TContestHandle): Boolean;

// Validate an ADIF GUID/UUID string.  Accepts 32 hex characters with
// optional 8-4-4-4-12 hyphens and optional `{...}` braces.  Used to gate
// the APP_N1MM_ID / APP_TR4W_ID assignment to exch.id.
function IsValidGUID(const guid: string): Boolean;

// =========================================================================
// Field-to-ContestExchange mapping
// =========================================================================

// Clear a TADIFRecordTemps to empty/false state.
procedure InitADIFRecordTemps(var temps: TADIFRecordTemps);

// Initialize a ContestExchange to a sane "no record yet" state for use
// by the ADIF parser.  Mirrors the relevant parts of the legacy
// ClearContestExchange (trdos/logdupe.pas) -- specifically the
// sentinels the parser depends on, e.g. Mode = NoMode so the MODE-
// handler's `if exch.Mode = NoMode` guard fires.  Does NOT touch
// MainUnit-global fields like ceContest's contest-specific defaults.
procedure InitContestExchangeForParse(var exch: ContestExchange);

// Apply a parsed field list to a ContestExchange record, populating
// "obvious" exch.X fields (CALL, BAND, MODE, FREQ, RST, SRX, STX, etc.)
// directly, and capturing the contest-aware temp values (SRX_STRING,
// STATE, ARRL_SECT, POTA_REF, etc.) into `temps` for the caller's
// contest-specific post-processing step.
//
// Returns False on parse error inside an individual field (e.g.
// StrToInt failure on RST_RCVD); the function continues processing the
// remaining fields and the partial exch is preserved.  Returns True
// when all fields were processed without exception.
function ApplyADIFFieldsToExchange(const fields: TADIFFieldList;
                                   var exch: ContestExchange;
                                   var temps: TADIFRecordTemps): Boolean;

(* THE TWO STEPS AFTER THE GENERIC READ -- M5a, 2026-10-01.

  ApplyADIFFieldsToExchange is contest-blind: it knows ADIF, not contests.
  What a record MEANS to its contest is decided only after the whole record is
  read, in this order, so the order its tags arrived in cannot matter:

    1. ApplyADIFCommonImport -- what every contest wants: a record with no
       OPERATOR gets the session's, and the received RST comes off the front
       of SRX_STRING to make ExchString (the exact inverse of what export
       prepends, ResolveSRXString);
    2. ApplyADIFContestImport -- the contest named by the record's CONTEST_ID
       is asked to interpret what the importer captured
       (TContestBase.ApplyADIFImport). The contest is
       uContestRegistry.ContestIdentity(exch.ceContest): its class, or the
       classless default.

  InterpretADIFRecord is both. They are separate so that a caller can put its
  own step between them for a contest that has no class yet. *)
procedure ApplyADIFCommonImport(const temps: TADIFRecordTemps;
                                const session: TADIFImportSession;
                                var exch: ContestExchange);
procedure ApplyADIFContestImport(const temps: TADIFRecordTemps;
                                 const session: TADIFImportSession;
                                 var exch: ContestExchange);
procedure InterpretADIFRecord(const temps: TADIFRecordTemps;
                              const session: TADIFImportSession;
                              var exch: ContestExchange);

(* A SESSION THAT STATES NOTHING: no operator, no exchange kind, no domestic
  multiplier. For an import that has no session to describe -- the unit tests'
  ImportADIFFromString -- so the classless default sees exactly what a contest
  with no domestic multipliers and no grid exchange sees. *)
function NeutralADIFImportSession: TADIFImportSession;

(* OUR STATION AS THE RECORD STATES IT -- log schema 3, stage 2.

  The row's my_* columns for an imported record: Source is mfsImported, and
  each value is the record's own tag. A TAG THE RECORD DOES NOT CARRY IS
  UNKNOWN -- empty, or a zone of 0 -- and is NEVER filled from today's
  settings (NY4I, ruling A): an import is not a QSO logged here.

    STATION_CALLSIGN            my_call
    MY_GRIDSQUARE               my_grid
    MY_STATE / MY_CNTY          my_state / my_county
    MY_ARRL_SECT                my_section
    MY_POTA_REF, else MY_SIG_INFO when MY_SIG is POTA      my_park
    MY_IOTA                     my_iota
    MY_DXCC                     my_country -- CTYEntityOfADIFDXCC, so only
                                a code ONE plain CTY entity carries
    MY_CQ_ZONE / MY_ITU_ZONE    my_cq_zone / my_itu_zone

  MY_COUNTRY (an entity NAME) is not read: nothing here maps a name to a CTY
  entity, and a guessed country is worse than an unknown one. my_continent is
  never in ADIF and stays unknown. *)
function MyFactsFromADIF(const temps: TADIFRecordTemps): TQsoMyFacts;

(* WHAT THE RECORD SAYS WE SENT -- its STX_STRING, verbatim, for the row's
  exchange_sent; '' when it has none. NEVER rebuilt from today's settings
  (stage 2, the D3 fix): that is what an import used to do, which stamped
  every imported QSO with the exchange the operator happens to send now. *)
function SentExchangeFromADIF(const temps: TADIFRecordTemps): AnsiString;

(* THE CTY ENTITY (its primary prefix, as cty.dat spells it) that ADIF DXCC
  code aDXCC names -- or '' when no entity, or more than one, carries it.
  The table maps prefix to code and several prefixes share a code ('*GM/s',
  Shetland, is credited to 279 with 'GM'); a starred prefix is a CTY-only
  region, so it is not counted, and a code still shared by two plain prefixes
  answers '' rather than guessing between them. *)
function CTYEntityOfADIFDXCC(aDXCC: integer): AnsiString;

(* TRUE WHEN aText IS ONE OR MORE ASCII LETTERS AND NOTHING ELSE -- false for
  empty text, a digit, a space or a hyphen. It is what a contest asks of an
  SRX_STRING to tell a domestic QTH from a serial number ('CT' against '123'),
  and it is Indy's IdGlobal.IsAlpha, which the main unit used for the same
  question, restated here because a contest class may not reach for the
  network library. *)
function ADIFTextIsAlphabetic(const aText: string): Boolean;

// =========================================================================
// Multi-record entry point
// =========================================================================

// Parse a multi-record ADIF string into `records`.  Splits on <EOR>
// (case-insensitive), lexes each record, applies the generic field mapping
// and then InterpretADIFRecord -- the contest named by the record's
// CONTEST_ID interprets what the mapping captured -- under
// NeutralADIFImportSession: there is no running contest here to describe.
// (MainUnit.ParseADIFRecord, which the operator's import runs, passes the
// session it really has.)
//
// Skips an optional ADIF header section (everything up to the first
// <EOH>, also case-insensitive).
//
// `records` is resized via SetLength to fit the parsed records.  Returns
// the count of records successfully parsed (= Length(records)).
function ImportADIFFromString(const s: string;
                              var records: TContestExchangeArray): Integer;

// =========================================================================
// Export side
// =========================================================================

type
   // Caller-supplied tail emitter.  Returns ADIF text to append between
   // EmitADIFRecord's output and the closing <EOR> for a single record.
   // Used by PostUnit.ExportToADIF to add contest-specific fields
   // (GRIDSQUARE / IOTA / ARRL_SECT / POTA MY_SIG / CLASS / STATION_CALLSIGN /
   // STX_STRING built from MainUnit globals / CQZ/ITUZ / CNTY from mo.DomList).
   // Tests pass nil to skip the tail entirely.
   //
   // aMyFacts is the record's OWN station (log schema 3): a tail that writes
   // something about our station writes it from there when the row captured
   // one, and from the session only for a row that never did (ruling A).
   TContestTailEmitter = function(const rec: ContestExchange;
                                  const aMyFacts: TQsoMyFacts): string;

   (* One TQsoMyFacts per record, in the records' order. *)
   TQsoMyFactsArray = array of TQsoMyFacts;

// Build one ADIF field as `<NAME:LEN>VALUE ` (trailing space for tag
// separation).  Empty value returns ''.
function EmitADIFField(const name, value: string): string;

// Build the ADIF header (ADIF_VER, CREATED_TIMESTAMP, PROGRAMID,
// PROGRAMVERSION, <EOH>).  Pure -- caller can prepend a banner line
// if desired.
function EmitADIFHeader(const programVersion: string): string;

// Build a single ADIF record from a ContestExchange.  Emits the
// "ContestExchange-driven" fields only -- fields whose values come
// from the record itself (call, band, mode, RST, etc.).  Does NOT
// emit `<EOR>` -- caller appends.
//
// Excludes fields that need MainUnit/trdos globals (STATION_CALLSIGN,
// STX_STRING via GetMyExchangeForExport, CNTY via mo.DomList,
// CQZ/ITUZ via the contest's ZoneMultiplierZones, POTA MY_* fields via MY PARK, ARRL-FD
// CLASS via MyFDClass etc.).  PostUnit.ExportToADIF provides those
// via the TContestTailEmitter callback.
//
// WHICH EXCHANGE FIELDS THE RECORD CARRIES IS THE CONTEST'S (2026-10-17,
// NY4I: "We should not just be exporting all possible fields"): QTH,
// PRECEDENCE, CHECK, NAME, the power tag, SRX, STX, TEN_TEN and AGE are
// TContestBase.EmitADIFReceivedFields -- each only where the contest's
// own ReceivedExchangeFields declares it.  The RST pair is
// TContestBase.EmitADIFReportFields and is every QSO's (NY4I: "Every QSO").
// This unit writes the fields
// that belong to the QSO, whatever the contest.
//
// aContest is the contest object to ask when the caller holds one that
// CARRIES THE STATION (uContestFactory.ActiveContest): a contest's field
// list can depend on the entrant (ARRL DX asks whether the entrant counts
// the DX multiplier), which ContestIdentity cannot know.  It is used only
// when it IS the record's own contest -- a logged QSO reads its record,
// never the live contest -- and nil, or another contest, asks
// ContestIdentity(rec.ceContest).
function EmitADIFRecord(const rec: ContestExchange;
                        aContest: TContestBase = nil): string;

// Build the entire ADIF document for the given records: header +
// (EmitADIFRecord(r) + tailEmitter(r) + <EOR>) for each record.
// `programVersion` is the value for the PROGRAMVERSION ADIF tag in
// the header.  `tailEmitter` may be nil -- in which case no contest-
// specific extras are added per record (suitable for tests).
// aContest is EmitADIFRecord's.
function ExportADIFToString(const records: TContestExchangeArray;
                            const programVersion: string;
                            tailEmitter: TContestTailEmitter;
                            aContest: TContestBase = nil): string; overload;

// THE SAME, WITH EACH RECORD'S OWN STATION -- aMyFacts[i] is records[i]'s,
// and is what EmitADIFMyStationFields writes after the tail. Shorter than
// records, or nil, means the records past its end were never captured.
function ExportADIFToString(const records: TContestExchangeArray;
                            const aMyFacts: TQsoMyFactsArray;
                            const programVersion: string;
                            tailEmitter: TContestTailEmitter;
                            aContest: TContestBase = nil): string; overload;

(* OUR STATION'S TAGS FOR ONE RECORD, FROM THE RECORD -- log schema 3, stage 2.

  '' FOR A ROW NEVER CAPTURED (my_source NULL). Such a row is written exactly
  as it was before schema 3: whatever the tail writes for it from the session
  (STATION_CALLSIGN, POTA's park) is the fallback NY4I ruled for (A), and
  nothing is added -- which is why no corpus fixture's export changes.

  For a captured row, in this order, each only when the row holds a value:
  STATION_CALLSIGN (only when the record's OPERATOR is not that call -- the
  rule the export has always applied, now asked of the record), MY_GRIDSQUARE,
  MY_STATE, MY_CNTY, MY_ARRL_SECT, MY_IOTA, MY_CQ_ZONE, MY_ITU_ZONE, MY_DXCC
  (from my_country, when the table knows its code), and the park as MY_SIG
  POTA, MY_SIG_INFO and MY_POTA_REF. POTA writes those three itself, from the
  record's park, so for a POTA QSO they are skipped by the rule below.

  A TAG ALREADY IN aAlreadyWritten IS SKIPPED. The contest's own fields come
  first and win -- POTA writes MY_STATE and MY_DXCC from its park list -- and
  one record must not carry a tag twice. *)
function EmitADIFMyStationFields(const rec: ContestExchange;
                                 const aFacts: TQsoMyFacts;
                                 const aAlreadyWritten: string): string;

// Format an integer with at least minLen digits (zero-padded) -- the
// width of ADIF's SRX, STX, TEN_TEN, AGE and CHECK as TR4W writes them.
// Public for TContestBase.EmitADIFReceivedFields.
function PadInt(n: Integer; minLen: Integer): string;

// Return the ADIF STATE of the WORKED station of rec -- the class of
// rec's contest decides (TContestBase.ADIFWorkedStationState; '' for
// every contest but the QSO parties).  Used by EmitADIFRecord.  Was
// GetStateForContest(c), which wrote the PARTY's state on every QSO --
// D7's rule, fixed at Q76/Q89 (NY4I, 2026-10-16).
function GetADIFStateForQSO(const rec: ContestExchange): string;

// ADIF's Primary Administrative Subdivision enumeration, for the four
// entities a North American QSO party hears from: is aCode (upper case)
// a STATE value ADIF allows for the CTY country aCountryID?
//   'K'   USA (DXCC 291)      the 48 contiguous states and DC
//   'KL'  Alaska (DXCC 6)     AK
//   'KH6' Hawaii (DXCC 110)   HI
//   'VE'  Canada (DXCC 1)     the 13 provinces and territories
// Any other country, or an unknown one, answers False: no value is
// invented for it.
function IsADIFPrimarySubdivision(const aCountryID, aCode: string): boolean;

// The same question by ADIF DXCC entity code (291, 6, 110, 1), for a caller
// that holds the code and not the CTY entity -- POTA's MY_STATE, whose DXCC
// comes from the park list.
function IsADIFPrimarySubdivisionOfDXCC(aDXCC: integer; const aCode: string): boolean;

// THE QTH A QSO PARTY JUDGES A QSO BY: the domestic table's resolved key
// (DomesticQTH -- 'Pin', 'AddVT', 'Md') when the record has one, else the
// QTH as logged (QTHString), trimmed.  The key, not the typed text, because
// an alias can be any length -- 'CON' is Connecticut, 'AD' an Addison
// County, VT -- while every county key in target/dom is longer than two
// letters and every state or province key is exactly two.
function ADIFPartyQTHKey(const aQso: ContestExchange): string;

// THE ADIF STATE OF A QSO PARTY'S WORKED STATION (Q76/Q89): aCountyState
// when the class found the QTH to be one of its counties (it says whose);
// else the QTH itself when it is a primary subdivision ADIF allows for the
// worked station's country (an out-of-state station's state, a VE's
// province); else '' -- DX, or anything else.  The rule every party class
// calls from its ADIFWorkedStationState.
function ADIFStateOfPartyQSO(const aCountyState: string;
                             const aQso: ContestExchange): string;

// Build the RST-normalized SRX_STRING value: if ExchString already
// starts with the literal RSTReceived (e.g. operator typed `599 HIL`),
// return ExchString unchanged; otherwise prepend `RSTReceived ` so
// the field is symmetric with STX_STRING.  Used by the export tail
// emitter for contests whose exchange convention includes an implied
// RST (ExchangeInformation.RST = True) -- state QPs and zone
// contests.  Contests whose exchange has no RST (FD, SS, Winter FD,
// etc.) should emit SRX_STRING = ExchString directly, NOT call this.
function ResolveSRXString(const rec: ContestExchange): string;

(* THE EXCHANGE INSIDE AN SRX_STRING -- the exact inverse of the above.

  ResolveSRXString PREPENDS the received RST so the field is symmetric with
  STX_STRING, so an importer that wants the exchange has to take it off
  again. Nothing did, and the result was visible the first time a log was
  imported and re-exported: NY4I's IARU set came back with a QTH of
  '59 8' -- the RST and the zone, stored as though they were a location.

  IT STRIPS ONLY A LEADING TOKEN THAT IS THE RECEIVED RST, which is what
  makes it safe on an exchange that has no RST at all. Field Day sends
  '1A EPA'; '1A' is not the RST, so nothing is removed. Guessing by shape
  -- 'the first token if it looks numeric' -- would eat the class in a
  contest that sends one. *)
function ExchangeFromSRXString(const aSRX: string;
                               aRSTReceived: integer): string;

implementation

(* IMPLEMENTATION-ONLY, so uADIF stays a leaf in its interface: TF is
  wanted for SetCharBuffer, which writes a fixed AnsiChar field through
  its own bounds instead of StrPLCopy plus a hand-passed High(). *)
uses
   TF,
   (* FindContestByADIFContestId -- which contest answers to a CONTEST_ID,
      including the ids it was exported under before a rename -- and
      ContestIdentity, the contest's own id for export. The contest owns both
      answers; this unit only caches the first. *)
   uContestRegistry,
   (* ADIFDXCCOfCTYEntity -- a CTY entity's ADIF DXCC code. *)
   uDXCCEntities;

var
   logger : TLogLogger;

   // Single-entry cache for GetContestByADIFName.  All QSOs in a typical
   // import file share the same CONTEST_ID, so this is a hot path.
   (* THE CACHE HOLDS THE ANSWER AND WHETHER THERE WAS ONE. It used to hold
      only the contest, and callers told "found" from "not found" by comparing
      the row's ADIFName with the input -- which cannot work once a contest
      also answers to a FORMER id. saveLastValid keeps an untouched cache from
      answering for an empty input. *)
   saveLastValid    : boolean;
   saveLastADIFName : string;
   saveLastContest  : TContestHandle;
   saveLastFound    : boolean;

   (* Single-entry cache for ContestOfRecordMode, for the same reason: a file
      is one contest and, nearly always, one or two modes. *)
   modeLastValid    : boolean;
   modeLastContest  : TContestHandle;
   modeLastMode     : ModeType;
   modeLastAnswer   : TContestHandle;

// ---------------------------------------------------------------------------
// Lexer helpers
// ---------------------------------------------------------------------------

procedure AppendField(var fields: TADIFFieldList;
                     const name, value: string);
var
   idx : Integer;
begin
   idx := Length(fields);
   SetLength(fields, idx + 1);
   fields[idx].Name := name;
   fields[idx].Value := value;
end;

// ---------------------------------------------------------------------------
// Lexer
// ---------------------------------------------------------------------------

function ParseADIFFieldsList(const s: string;
                             out fields: TADIFFieldList): Boolean;
var
   p           : Integer;
   sLen        : Integer;
   gtPos       : Integer;
   tagBody     : string;
   tagUpper    : string;
   tagName     : string;
   tagLenStr   : string;
   tagLen      : Integer;
   colonPos    : Integer;
   secondColon : Integer;
   value       : string;
begin
   Result := False;
   SetLength(fields, 0);
   sLen := Length(s);
   p := 1;

   while p <= sLen do
      begin
      // Skip text between tags
      while (p <= sLen) and (s[p] <> '<') do
         begin
         Inc(p);
         end;
      if p > sLen then
         begin
         Break;
         end;

      Inc(p);  // skip '<'

      // Find matching '>'
      gtPos := p;
      while (gtPos <= sLen) and (s[gtPos] <> '>') do
         begin
         Inc(gtPos);
         end;
      if gtPos > sLen then
         begin
         // '<' without matching '>' — malformed; stop with what we have
         if Assigned(logger) then
            begin
            logger.Warn('[ADIF lexer] unclosed tag at position %d', [p - 1]);
            end;
         Exit;
         end;

      tagBody := Copy(s, p, gtPos - p);
      p := gtPos + 1;  // advance past '>'

      // <EOR> terminates a QSO record.  <EOH> only ends the optional
      // ADIF header (spec IV.A.2: an ADI file is an optional Header,
      // terminated by <EOH>, followed by one or more <EOR> records; a
      // headerless file starts straight into records).  A full document
      // reaches this single-record lexer -- the WSJT-X "Logged ADIF" UDP
      // message is <adif_ver><programid><EOH><call...><EOR> -- so skip
      // <EOH> and keep parsing the record that follows rather than
      // stopping at the header boundary.  Restores the pre-Issue-#887
      // behaviour, where the inline parser terminated on <EOR> only.
      tagUpper := AnsiUpperCase(tagBody);
      if tagUpper = 'EOR' then
         begin
         Result := True;
         Exit;
         end;
      if tagUpper = 'EOH' then
         begin
         Continue;
         end;

      // Parse '<NAME:LEN>' or '<NAME:LEN:TYPE>'
      colonPos := AnsiPos(':', tagBody);
      if colonPos = 0 then
         begin
         if Assigned(logger) then
            begin
            logger.Warn('[ADIF lexer] tag without length: <%s>', [tagBody]);
            end;
         Continue;
         end;

      tagName   := Copy(tagBody, 1, colonPos - 1);
      tagLenStr := Copy(tagBody, colonPos + 1, Length(tagBody) - colonPos);

      // Strip optional ':TYPE' suffix
      secondColon := AnsiPos(':', tagLenStr);
      if secondColon > 0 then
         begin
         tagLenStr := Copy(tagLenStr, 1, secondColon - 1);
         end;

      if not TryStrToInt(tagLenStr, tagLen) then
         begin
         if Assigned(logger) then
            begin
            logger.Warn('[ADIF lexer] tag <%s> has non-numeric length [%s]',
                        [tagName, tagLenStr]);
            end;
         Continue;
         end;

      if tagLen < 0 then
         begin
         if Assigned(logger) then
            begin
            logger.Warn('[ADIF lexer] tag <%s> has negative length %d',
                        [tagName, tagLen]);
            end;
         Continue;
         end;

      // Read exactly tagLen characters as the value
      if p + tagLen - 1 > sLen then
         begin
         // truncated value — take whatever is left, then stop
         value := Copy(s, p, sLen - p + 1);
         AppendField(fields, tagName, value);
         if Assigned(logger) then
            begin
            logger.Warn('[ADIF lexer] tag <%s:%d> truncated; got %d bytes',
                        [tagName, tagLen, Length(value)]);
            end;
         Exit;
         end;

      value := Copy(s, p, tagLen);
      p := p + tagLen;
      AppendField(fields, tagName, value);
      end;

   // Ran off the end without seeing <EOR> or <EOH>
   Result := False;
end;

// ---------------------------------------------------------------------------
// Per-field type-conversion helpers
// ---------------------------------------------------------------------------

function GetADIFBand(sBand: string): BandType;
var
   sBandLower : string;
   iBand      : BandType;
   entry      : string;
begin
   Result := NoBand;
   // Reject empty input — ADIFBANDSTRINGSARRAY has nil entries for the
   // tail of BandType (placeholders), and an empty string would match
   // those PChar(nil) entries on string comparison, yielding a spurious
   // band.  No legitimate ADIF input has BAND=''.
   if sBand = '' then
      begin
      Exit;
      end;
   sBandLower := AnsiLowerCase(sBand);
   for iBand := Low(BandType) to High(BandType) do
      begin
      entry := ADIFBANDSTRINGSARRAY[iBand];
      (* Empty, not nil: bands ADIF has no token for are '' in the table
        now rather than a null pointer, and an empty token must never match
        an empty search string either. *)
      if (entry <> '') and (sBandLower = entry) then
         begin
         Result := iBand;
         Break;
         end;
      end;
end;

function GetADIFMode(sMode: string): ModeAndExtendedModeType;
begin
   // Default extended mode in case lookup hits the else branch — keeps
   // the field deterministic when MODE is unrecognized.
   Result.msmExtendedMode := eNoMode;

   // The lookup list mirrors what TR4W's export side emits.  Several
   // entries (CW-R, RTTY-R, FM-N, C4FM, etc.) are TR4W-specific
   // extended modes that the export puts in the ADIF MODE field
   // (not SUBMODE), so the import must accept them there too for
   // round-trip.  Whether that is fully ADIF-spec-correct is a
   // separate question; this matches existing export behaviour.
   case AnsiIndexText(AnsiUpperCase(sMode),
                      ['CW', 'SSB', 'AM', 'FM', 'FT8',
                       'RTTY', 'MFSK', 'PSK31', 'PSK', 'DATA',
                       'CW-R', 'RTTY-R', 'DATA-R', 'PSK-R',
                       'JT65', 'PSK63', 'DATA-FM',
                       'FM-N', 'AM-N', 'WFM', 'C4FM', 'D-STAR']) of
      0:                              // CW
         begin
         Result.msmMode := CW;
         Result.msmExtendedMode := eCW;
         end;
      1:                              // SSB
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eSSB;
         end;
      2:                              // AM
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eAM;
         end;
      3:                              // FM
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eFM;
         end;
      4:                              // FT8
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eFT8;
         end;
      5:                              // RTTY
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eRTTY;
         end;
      6:                              // MFSK
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eMFSK;
         end;
      7, 8:                           // PSK31, PSK
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := ePSK31;
         end;
      9:                              // DATA  (generic digital)
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eData;
         end;

      // --- CW family ---
      10:                             // CW-R
         begin
         Result.msmMode := CW;
         Result.msmExtendedMode := eCW_R;
         end;

      // --- Digital family (reverses + protocols) ---
      11:                             // RTTY-R
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eRTTY_R;
         end;
      12:                             // DATA-R
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eData_R;
         end;
      13:                             // PSK-R
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := ePSK_R;
         end;
      14:                             // JT65
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eJT65;
         end;
      15:                             // PSK63
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := ePSK63;
         end;
      16:                             // DATA-FM
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eData_FM;
         end;

      // --- Phone family (narrowband + digital voice) ---
      17:                             // FM-N
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eFM_N;
         end;
      18:                             // AM-N
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eAM_N;
         end;
      19:                             // WFM
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eWFM;
         end;
      20:                             // C4FM (Yaesu digital voice)
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eC4FM;
         end;
      21:                             // D-STAR (Icom digital voice)
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eDStar;
         end;
   else
      Result.msmMode := NoMode;
   end;
end;

function GetADIFSubMode(sSubMode: string): ModeAndExtendedModeType;
begin
   case AnsiIndexText(AnsiUpperCase(sSubMode),
                      ['FT4', 'JS8', 'USB', 'LSB', 'PSK31']) of
      0:                              // FT4
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eFT4;
         end;
      1:                              // JS8
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := eJS8;
         end;
      2:                              // USB
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eUSB;
         end;
      3:                              // LSB
         begin
         Result.msmMode := Phone;
         Result.msmExtendedMode := eLSB;
         end;
      4:                              // PSK31
         begin
         Result.msmMode := Digital;
         Result.msmExtendedMode := ePSK31;
         end;
   else
      Result.msmMode := NoMode;
   end;
end;

function ADIFDateStringToQSOTime(sDate: string;
                                 var qsoTime: TQSOTime): Boolean;
begin
   Result := False;
   try
      if Length(sDate) = 8 then
         begin
         // Strict StrToInt (raises on non-numeric) is intentional: the enclosing
         // try/except converts the raise into a False return, which is this
         // function's contract -- reject a malformed date rather than silently
         // parsing 'XX' as 0. (StrToIntDef would defeat that; see the D12
         // TF.StrToInt->StrToIntDef sweep, which regressed this site.)
         qsoTime.qtYear  := Ord(SysUtils.StrToInt(MidStr(sDate, 1, 4)) mod 100);
         qsoTime.qtMonth := Ord(SysUtils.StrToInt(MidStr(sDate, 5, 2)));
         qsoTime.qtDay   := Ord(SysUtils.StrToInt(MidStr(sDate, 7, 2)));
         Result := True;
         end;
   except
      Result := False;
   end;
end;

function ADIFTimeStringToQSOTime(sTime: string;
                                 var qsoTime: TQSOTime): Boolean;
begin
   Result := False;
   if Length(sTime) in [4, 6] then
      begin
      try
         // Strict StrToInt (raises on non-numeric) is intentional -- the
         // try/except turns the raise into a False return, rejecting a malformed
         // time instead of silently parsing e.g. '15XX' as 0. Same regression the
         // D12 TF.StrToInt->StrToIntDef sweep introduced in the date parser above.
         qsoTime.qtHour   := Ord(SysUtils.StrToInt(MidStr(sTime, 1, 2)));
         qsoTime.qtMinute := Ord(SysUtils.StrToInt(MidStr(sTime, 3, 2)));
         if Length(sTime) = 6 then
            begin
            qsoTime.qtSecond := Ord(SysUtils.StrToInt(MidStr(sTime, 5, 2)))
            end
         else
            begin
            qsoTime.qtSecond := 0;
            end;
         Result := True;
      except
         Result := False;
      end;
      end;
end;

function GetContestByADIFName(const sADIFName: string;
                              out aContest: TContestHandle): Boolean;
begin
   if saveLastValid and (sADIFName = saveLastADIFName) then
      begin
      aContest := saveLastContest;
      Result := saveLastFound;
      Exit;
      end;

   Result := FindContestByADIFContestId(sADIFName, aContest);

   saveLastADIFName := sADIFName;
   saveLastContest  := aContest;
   saveLastFound    := Result;
   saveLastValid    := True;
end;

(* THE RECORD'S CONTEST, NOW THAT ITS MODE IS KNOWN -- M7b batch 2. See
  uContestRegistry.ContestOfADIFRecordMode; this only caches it. *)
function ContestOfRecordMode(aContest: TContestHandle; aMode: ModeType): TContestHandle;
begin
   if modeLastValid               and
      (aContest = modeLastContest) and
      (aMode = modeLastMode)       then
      begin
      Result := modeLastAnswer;
      Exit;
      end;

   Result := ContestOfADIFRecordMode(aContest, aMode);

   modeLastContest := aContest;
   modeLastMode    := aMode;
   modeLastAnswer  := Result;
   modeLastValid   := True;
end;

// ---------------------------------------------------------------------------
// IsValidGUID
//
// Standalone GUID validator that does NOT depend on TPerlRegEx (the
// logstuff.pas version uses TPerlRegEx, which would drag in a much
// heavier dependency surface).  Accepts:
//   - 32 raw hex characters (no separators)
//   - 8-4-4-4-12 hyphenated form (36 characters)
//   - Either of the above wrapped in `{...}` braces
// ---------------------------------------------------------------------------

function IsValidGUID(const guid: string): Boolean;
const
   HEX_CHARS = ['0'..'9', 'a'..'f', 'A'..'F'];
var
   s        : string;
   i        : Integer;
   hexCount : Integer;
begin
   Result := False;
   if guid = '' then
      begin
      Exit;
      end;

   s := guid;

   // Strip optional surrounding braces
   if (Length(s) >= 2) and (s[1] = '{') and (s[Length(s)] = '}') then
      begin
      s := Copy(s, 2, Length(s) - 2);
      end;

   if (Length(s) <> 32) and (Length(s) <> 36) then
      begin
      Exit;
      end;

   hexCount := 0;
   for i := 1 to Length(s) do
      begin
      if s[i] in HEX_CHARS then
         begin
         Inc(hexCount)
         end
      else if s[i] = '-' then
         begin
         // Hyphens only at positions 9, 14, 19, 24 in 8-4-4-4-12 layout
         if (Length(s) <> 36) or
            ((i <> 9) and (i <> 14) and (i <> 19) and (i <> 24)) then
            begin
            Exit;
            end;
         end
      else
         begin
         Exit;
         end;
      end;

   Result := hexCount = 32;
end;

// ---------------------------------------------------------------------------
// Field-to-ContestExchange mapping
// ---------------------------------------------------------------------------

procedure InitADIFRecordTemps(var temps: TADIFRecordTemps);
begin
   temps.SRX_String := '';
   temps.STX_String := '';
   temps.State      := '';
   temps.ARRL_Sect  := '';
   temps.VE_Prov    := '';
   temps.POTARef    := '';
   temps.SIG        := '';
   temps.SIG_Info   := '';
   temps.GridSquare := '';
   temps.FOC_Num    := '';
   temps.APP_HQ     := '';
   temps.DOK        := '';
   temps.IOTA       := '';
   temps.N1MM_Exchange1 := '';
   temps.MyCall       := '';
   temps.MyGridSquare := '';
   temps.MyState      := '';
   temps.MyCounty     := '';
   temps.MyARRLSect   := '';
   temps.MySig        := '';
   temps.MySigInfo    := '';
   temps.MyPOTARef    := '';
   temps.MyIOTA       := '';
   temps.MyDXCC       := '';
   temps.MyCQZone     := '';
   temps.MyITUZone    := '';
   temps.FromWSJTX  := False;
end;

const
   // Order MUST match the TADIF_Fields enum declaration.  Adding a field
   // requires updating BOTH this array AND the enum.
   ADIF_FIELD_NAMES : array[0..59] of string = (
      // ADIF spec field name is `CQZ` (no underscore).  The original
      // import lookup had `CQ_Z` which never matched real-world ADIF
      // exports -- the tAdifCQ_Z handler was effectively dead until
      // this fix.  Zone parsing for CQ-WW used to rely on the SRX_STRING
      // post-processing in MainUnit's contest tail.  Surfaced by the
      // CQ-WW-CW fixture test (uTestADIFFixtures).
      'ARRL_SECT', 'BAND', 'CALL', 'CHECK', 'CLASS', 'CQZ',
      'CONTEST_ID', 'CNTY', 'FOC_NUM', 'GRIDSQUARE', 'FREQ', 'FREQ_RX',
      'IOTA', 'ITUZ', 'MODE', 'NAME', 'OPERATOR', 'PRECEDENCE',
      'QSO_DATE', 'QSO_DATE_OFF', 'TIME_ON', 'TIME_OFF',
      'RST_RCVD', 'RST_SENT', 'RX_PWR', 'SRX', 'SRX_STRING',
      'STATE', 'STX', 'STX_STRING', 'SUBMODE', 'TEN_TEN',
      'VE_PROV', 'APP_TR4W_HQ', 'APP_N1MM_HQ', 'STATION_CALLSIGN',
      'QTH', 'PROGRAMID', 'APP_N1MM_EXCHANGE1', 'APP_N1MM_ID',
      'APP_TR4W_ID', 'SIG', 'SIG_INFO', 'POTA_REF',
      'APP_TR4W_ROVERCALL',
      // X-QSO marker fields (Issue #750) -- order must match the enum
      'APP_TR4W_CLAIMEDQSO', 'APP_N1MM_CLAIMEDQSO', 'APP_DXLOG_XQSO',
      'DOK',
      // Our station (schema 3) -- order must match the enum
      'MY_GRIDSQUARE', 'MY_STATE', 'MY_CNTY', 'MY_ARRL_SECT',
      'MY_SIG', 'MY_SIG_INFO', 'MY_POTA_REF', 'MY_IOTA',
      'MY_DXCC', 'MY_CQ_ZONE', 'MY_ITU_ZONE');

// Index of aName in ADIF_FIELD_NAMES, or -1.  Case-insensitive, ASCII-only.
//
// This replaced AnsiIndexText(AnsiUpperCase(fieldName), ADIF_FIELD_NAMES).
// AnsiIndexText takes an open array whose element type is the RTL's OWN
// `string`, and the two compilers do not agree on what that is: under FPC the
// RTL is compiled 8-bit while this unit is not, so a named UnicodeString table
// will not bind.  (The inline ['AI','BI',...] literals elsewhere in the tree
// coerce element-by-element and are unaffected.)
//
// Doing the lookup here also drops the AnsiUpperCase copy that was allocated
// for every field of every QSO on the import path.  ADIF field names are ASCII
// by specification, so ASCII-only folding is exactly right -- and it is the
// same restraint StrUpper observes so CP1251 text is never mis-folded.
function ADIFFieldIndex(const aName: string): integer;
var
   i, j, n : integer;
   a, b    : Char;
   match   : boolean;
begin
   Result := -1;
   n := Length(aName);

   for i := Low(ADIF_FIELD_NAMES) to High(ADIF_FIELD_NAMES) do
      begin
      if Length(ADIF_FIELD_NAMES[i]) <> n then
         begin
         Continue;
         end;

      match := True;
      for j := 1 to n do
         begin
         a := aName[j];
         if (a >= 'a') and (a <= 'z') then
            begin
            a := Char(Ord(a) - 32);
            end;

         b := ADIF_FIELD_NAMES[i][j];
         if (b >= 'a') and (b <= 'z') then
            begin
            b := Char(Ord(b) - 32);
            end;

         if a <> b then
            begin
            match := False;
            Break;
            end;
         end;

      if match then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function ApplyADIFFieldsToExchange(const fields: TADIFFieldList;
                                   var exch: ContestExchange;
                                   var temps: TADIFRecordTemps): Boolean;
var
   i                    : Integer;
   fieldName            : string;
   fieldValue           : string;
   tempRST              : string;
   neFreq               : Extended;
   msm                  : ModeAndExtendedModeType;
   contest              : TContestHandle;
   saveDecimalSeparator : Char;
   haveRoverCall        : Boolean;
   contestFromId        : Boolean;
begin
   Result := True;
   InitADIFRecordTemps(temps);
   haveRoverCall := False;
   contestFromId := False;

   for i := 0 to High(fields) do
      begin
      fieldName  := fields[i].Name;
      fieldValue := fields[i].Value;

      try
         case TADIF_Fields(ADIFFieldIndex(fieldName)) of

            tAdifARRL_SECT:
               temps.ARRL_Sect := fieldValue;

            tAdifBAND:
               exch.Band := GetADIFBand(fieldValue);

            tAdifCALL:
               // If we have already seen APP_TR4W_ROVERCALL in this
               // record, it carries the full rover form (KG1S/MON)
               // and we keep that instead of the bare CALL value.
               if not haveRoverCall then
                  begin
                  exch.Callsign := AnsiUpperCase(fieldValue);
                  end;

            tAdifAPP_TR4W_ROVERCALL:
               begin
               exch.Callsign := AnsiUpperCase(fieldValue);
               haveRoverCall := True;
               end;

            tAdifCHECK:
               exch.Check := StrToIntDef(fieldValue, 0);

            tAdifCLASS:
               exch.ceClass := AnsiUpperCase(fieldValue);

            tAdifCQ_Z:
               exch.Zone := StrToIntDef(fieldValue, 0);

            tAdifCONTEST_ID:
               begin
               if GetContestByADIFName(fieldValue, contest) then
                  begin
                  exch.ceContest := contest;
                  contestFromId := True;
                  end;
               end;

            tAdifCNTY:
               logger.Info('[ApplyADIFFields] CNTY=%s but no destination field',
                           [fieldValue]);

            tAdifFOC_NUM:
               temps.FOC_Num := fieldValue;

            tAdifGRIDSQUARE:
               temps.GridSquare := fieldValue;

            tAdifIOTA:
               temps.IOTA := fieldValue;

            tAdifDOK:
               temps.DOK := fieldValue;

            (* OUR STATION, AS THE RECORD STATES IT -- MyFactsFromADIF. *)
            tAdifMY_GRIDSQUARE:
               temps.MyGridSquare := fieldValue;
            tAdifMY_STATE:
               temps.MyState := fieldValue;
            tAdifMY_CNTY:
               temps.MyCounty := fieldValue;
            tAdifMY_ARRL_SECT:
               temps.MyARRLSect := fieldValue;
            tAdifMY_SIG:
               temps.MySig := fieldValue;
            tAdifMY_SIG_INFO:
               temps.MySigInfo := fieldValue;
            tAdifMY_POTA_REF:
               temps.MyPOTARef := fieldValue;
            tAdifMY_IOTA:
               temps.MyIOTA := fieldValue;
            tAdifMY_DXCC:
               temps.MyDXCC := fieldValue;
            tAdifMY_CQ_ZONE:
               temps.MyCQZone := fieldValue;
            tAdifMY_ITU_ZONE:
               temps.MyITUZone := fieldValue;

            tAdifFREQ:
               begin
               saveDecimalSeparator := FormatSettings.DecimalSeparator;
               try
                  FormatSettings.DecimalSeparator := '.';
                  neFreq := StrToFloat(fieldValue);
                  neFreq := neFreq * 1000000;
                  exch.Frequency := Trunc(neFreq);
               finally
                  FormatSettings.DecimalSeparator := saveDecimalSeparator;
               end;
               end;

            tAdifITUZ:
               exch.Zone := StrToIntDef(fieldValue, 0);

            tAdifMODE:
               if exch.Mode = NoMode then
                  begin
                  msm := GetADIFMode(fieldValue);
                  exch.Mode    := msm.msmMode;
                  exch.ExtMode := msm.msmExtendedMode;
                  end;

            tAdifNAME:
               exch.Name := fieldValue;

            tAdifOPERATOR:
               SetCharBuffer(exch.ceOperator, fieldValue);

            tAdifPRECEDENCE:
               if Length(fieldValue) > 0 then
                  begin
                  exch.Precedence := AnsiChar(fieldValue[1]);
                  end;

            tAdifQSO_DATE:
               ADIFDateStringToQSOTime(fieldValue, exch.tSysTime);

            tAdifTIME_ON, tAdifTIME_OFF:
               ADIFTimeStringToQSOTime(fieldValue, exch.tSysTime);

            tAdifRST_RCVD:
               begin
               tempRST := fieldValue;
               // WSJT-X uses signed dB SNR like "+05" / "-12".  Strip
               // the sign so StrToIntDef can parse the magnitude.  The
               // sign is dropped (TR uses a Word; negative SNRs are
               // not representable in the legacy log format).
               if temps.FromWSJTX and (Pos('+', fieldValue) > 0) then
                  begin
                  tempRST := AnsiMidStr(fieldValue, 2, Length(fieldValue));
                  end;
               exch.RSTReceived := StrToIntDef(tempRST, 599);
               end;

            tAdifRST_SENT:
               begin
               tempRST := fieldValue;
               if temps.FromWSJTX and (Pos('+', fieldValue) > 0) then
                  begin
                  tempRST := AnsiMidStr(fieldValue, 2, Length(fieldValue));
                  end;
               exch.RSTSent := StrToIntDef(tempRST, 599);
               end;

            tAdifRX_PWR:
               exch.Power := fieldValue;

            tAdifSRX:
               exch.NumberReceived := StrToIntDef(fieldValue, 0);

            tAdifSRX_STRING:
               temps.SRX_String := fieldValue;

            tAdifSTATE:
               temps.State := fieldValue;

            tAdifSTX:
               exch.NumberSent := StrToIntDef(fieldValue, 0);

            tAdifSTX_STRING:
               temps.STX_String := fieldValue;

            tAdifSUBMODE:
               begin
               msm := GetADIFSubMode(fieldValue);
               exch.Mode    := msm.msmMode;
               exch.ExtMode := msm.msmExtendedMode;
               end;

            tAdifTEN_TEN:
               exch.TenTenNum := StrToIntDef(fieldValue, 0);

            tAdifVE_PROV:
               temps.VE_Prov := fieldValue;

            tAdifAPP_TR4W_HQ, tAdifAPP_N1MM_HQ:
               temps.APP_HQ := fieldValue;

            (* OUR CALL AS SIGNED -- the row's my_call (schema 3). It was
              ignored on import until stage 2. *)
            tAdifSTATION_CALLSIGN:
               temps.MyCall := fieldValue;

            tAdifQTH:
               exch.QTHString := fieldValue;

            tAdifPROGRAMID:
               if fieldValue = 'WSJT-X' then
                  begin
                  temps.FromWSJTX := True;
                  end;

            tAdifAPP_N1MM_EXCHANGE1:
               (* CAPTURED, NOT READ AS IT GOES BY. N1MM stores the contest's
                  own exchange item here -- a class for the Field Days instead
                  of the standard CLASS tag, a membership number for the FOC
                  Marathon -- so what it MEANS is the contest's. The contest
                  is known only when CONTEST_ID has been read, and ADIF fixes
                  no field order: the arm that used to stand here read
                  exch.ceContest as it went by, so a record with this tag
                  AHEAD of CONTEST_ID was interpreted for the SESSION's
                  contest and not the record's. The contest interprets it
                  after the whole record is in (ApplyADIFImport). *)
               temps.N1MM_Exchange1 := fieldValue;

            tAdifAPP_N1MM_ID, tAdifAPP_TR4W_ID:
               if IsValidGUID(fieldValue) then
                  begin
                  exch.id := fieldValue;
                  end;

            tAdifSIG:
               temps.SIG := fieldValue;

            tAdifSIG_INFO:
               temps.SIG_Info := fieldValue;

            tAdifPOTAREF:
               temps.POTARef := fieldValue;

            // X-QSO markers (Issue #750).  Three different field
            // conventions in the wild; recognize all of them so an ADIF
            // exported from TR4W, N1MM, or DXLog.net round-trips into
            // TR4W with the X-QSO flag preserved.  TR4W and N1MM use
            // CLAIMEDQSO = '0' to mean "X-QSO"; DXLog.net uses XQSO = 'Y'.
            // Any non-claimed value sets the flag; presence with the
            // claimed value (TR4W/N1MM '1', DXLog '0' or 'N') leaves it
            // False so we don't overwrite a True already set by an
            // earlier field on the same record.
            tAdifAPP_TR4W_CLAIMEDQSO, tAdifAPP_N1MM_CLAIMEDQSO:
               if Trim(fieldValue) = '0' then
                  begin
                  exch.ceXQSO := True;
                  end;

            tAdifAPP_DXLOG_XQSO:
               if (Trim(fieldValue) = 'Y') or (Trim(fieldValue) = 'y') then
                  begin
                  exch.ceXQSO := True;
                  end;

         else
            // Unknown / unhandled field.  Silently accept anything
            // prefixed with APP_ (third-party extensions).  Log others.
            if Copy(fieldName, 1, 4) <> 'APP_' then
               begin
               logger.Warn('[ApplyADIFFields] %s is present but no handler',
                           [fieldName]);
               end;
         end;

      except
         on e: Exception do
            begin
            Result := False;
            logger.Warn('[ApplyADIFFields] %s=[%s] threw: %s',
                        [fieldName, fieldValue, e.Message]);
            end;
      end;
      end;

   (* ONE ID, TWO CONTESTS: TOLD APART BY THE MODE, ONCE THE WHOLE RECORD IS
      READ -- M7b batch 2 (design 8.2k). RSGB-ROLO names both RSGB RoPoCo
      runnings; the contest that runs in this record's mode is its contest.
      After the loop, so MODE may arrive before or after CONTEST_ID. Only a
      contest that came FROM the id is refined: one the caller set has no id
      to share. *)
   if contestFromId then
      begin
      exch.ceContest := ContestOfRecordMode(exch.ceContest, exch.Mode);
      end;
end;

// ---------------------------------------------------------------------------
// Multi-record entry point
// ---------------------------------------------------------------------------

// Initialize a ContestExchange to a sane "no record yet" state.  Matches
// the parts of MainUnit/trdos's ClearContestExchange that the ADIF
// parser depends on (specifically: Mode = NoMode so the MODE-handler
// guard `if exch.Mode = NoMode then ...` fires, and a few other
// sentinels that distinguish "not seen" from "seen as zero").  Does NOT
// touch ceContest (caller's job, normally via the ADIF CONTEST_ID
// field) or any field that depends on MainUnit globals.
procedure InitContestExchangeForParse(var exch: ContestExchange);
const
   // ClearContestExchange uses -1 / MAXWORD / MAXBYTE as "not set" sentinels.
   // Windows.MAXWORD is $FFFF; declared locally to avoid `uses Windows`.
   SENTINEL_WORD = $FFFF;
begin
   FillChar(exch, SizeOf(exch), 0);
   exch.Band           := NoBand;
   exch.Mode           := NoMode;
   exch.ExtMode        := eNoMode;
   exch.NumberReceived := SENTINEL_WORD;
   exch.NumberSent     := SENTINEL_WORD;
   exch.TenTenNum      := SENTINEL_WORD;
   exch.Zone           := DUMMYZONE;
   exch.QTH.Zone       := DUMMYZONE;
end;

procedure ApplyADIFCommonImport(const temps: TADIFRecordTemps;
                                const session: TADIFImportSession;
                                var exch: ContestExchange);
begin
   // fix up operator
   if exch.ceOperator = '' then
      begin
      exch.ceOperator := session.Operator;
      end;

   (* THE RECEIVED RST COMES OFF HERE, ONCE, FOR EVERY CONTEST. The export
     side prepends it unconditionally (ResolveSRXString) to make the field
     symmetric with STX_STRING, so this is the exact inverse and belongs at
     the same level -- not in a contest's interpretation, which is where the
     first two instances of this fault were fixed one at a time. *)
   if Length(temps.SRX_String) > 0 then
      begin
      exch.ExchString := ExchangeFromSRXString(temps.SRX_String,
                                               exch.RSTReceived);
      end;
end;

procedure ApplyADIFContestImport(const temps: TADIFRecordTemps;
                                 const session: TADIFImportSession;
                                 var exch: ContestExchange);
begin
   ContestIdentity(exch.ceContest).ApplyADIFImport(temps, session, exch);
end;

procedure InterpretADIFRecord(const temps: TADIFRecordTemps;
                              const session: TADIFImportSession;
                              var exch: ContestExchange);
begin
   ApplyADIFCommonImport(temps, session, exch);
   ApplyADIFContestImport(temps, session, exch);
end;

function NeutralADIFImportSession: TADIFImportSession;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ReceivesGridSquare := False;
   Result.CountsGridSquares := False;
   Result.DoingDomesticMults := False;
end;

function ADIFTextIsAlphabetic(const aText: string): Boolean;
var
   i: Integer;
begin
   Result := False;
   if Length(aText) = 0 then
      begin
      Exit;
      end;

   for i := 1 to Length(aText) do
      begin
      if not (((aText[i] >= 'a') and (aText[i] <= 'z')) or
              ((aText[i] >= 'A') and (aText[i] <= 'Z'))) then
         begin
         Exit;
         end;
      end;
   Result := True;
end;

function ImportADIFFromString(const s: string;
                              var records: TContestExchangeArray): Integer;
var
   p          : Integer;
   sLen       : Integer;
   eorPosUp   : Integer;
   eohPosUp   : Integer;
   sUpper     : string;
   chunk      : string;
   fields     : TADIFFieldList;
   exch       : ContestExchange;
   temps      : TADIFRecordTemps;
   recordEnd  : Integer;
begin
   Result := 0;
   SetLength(records, 0);
   sLen := Length(s);
   if sLen = 0 then
      begin
      Exit;
      end;

   sUpper := AnsiUpperCase(s);

   // Skip optional ADIF header (everything up to and including <EOH>).
   eohPosUp := AnsiPos('<EOH>', sUpper);
   if eohPosUp > 0 then
      begin
      p := eohPosUp + 5   // length of '<EOH>'
      end
   else
      begin
      p := 1;
      end;

   while p <= sLen do
      begin
      // Find the next <EOR> (case-insensitive) starting at p.
      eorPosUp := PosEx('<EOR>', sUpper, p);
      if eorPosUp = 0 then
         begin
         Break;  // no more complete records
         end;

      recordEnd := eorPosUp + 5;  // include the '<EOR>' itself
      chunk := Copy(s, p, recordEnd - p);

      // Lex + apply
      ParseADIFFieldsList(chunk, fields);
      InitContestExchangeForParse(exch);
      InitADIFRecordTemps(temps);
      ApplyADIFFieldsToExchange(fields, exch, temps);
      InterpretADIFRecord(temps, NeutralADIFImportSession, exch);

      SetLength(records, Result + 1);
      records[Result] := exch;
      Inc(Result);

      p := recordEnd;
      end;
end;

// ---------------------------------------------------------------------------
// Export side
// ---------------------------------------------------------------------------

(* ONE DEFINITION, IN VC, WHERE THE TABLE IS.

   THIS WAS A 13-ARM `case c of FLORIDAQSOPARTY: Result := 'FL'`, AND SO WAS
   PostUnit's -- two hand-typed copies of a fact ContestsArray already carries
   as its P index. Both were incomplete in the same way: New York, Washington,
   Arizona and Virginia are state QSO parties with a two-letter StateName in
   QSOParties and appeared in neither copy, so their ADIF export emitted no
   STATE field at all. That is the drift CLAUDE.md describes -- the newest bug
   living in the oldest copy, with nothing in the build pointing at it.

   THE FUNCTION IS KEPT RATHER THAN THE CALL SITES REPOINTED, because the name
   is what documents the intent at the two places that use it and it is named
   in the ADIF verifier's README.

   IT ASKS THE CONTEST SINCE M10 S6, and asks its QSOPartyArea, NOT its
   HostState. VC.USQSOPartyStateName -- the table read this replaced, now
   deleted -- answered the QSOParties entry's StateName when that was two
   letters, else ''. QSOPartyArea IS that StateName for every contest
   (Test_MovedRowValuesStillMatchTheArray), so the same two-letter test on
   it gives byte-identical export. HostState would NOT: British Columbia
   states 'BC' while its area is 'VE7', so asking HostState would start
   writing STATE and CNTY on every BCQP QSO. That may well be right -- ADIF's
   STATE holds a Canadian province -- but it is a behaviour change, and it
   is an open question for NY4I, not a side effect of removing a table.

   NY4I ANSWERED IT (Q89, 2026-10-16): STATE yes, CNTY no. The same day
   (Q76) he fixed the rule itself: "if you write STATE in ADIF,
   that is the state of the worked station" (the entrant's is MY_STATE).
   The function above wrote the HOST's state on EVERY QSO carrying a QTH --
   D7's `if (stateForQP <> '') and (rec.QTHString <> '')` -- so a Michigan
   log said STATE:MI for a station in DC. It is replaced by the class's
   per-QSO answer, TContestBase.ADIFWorkedStationState: a host county gives
   the host's state, an out-of-state station's own state or province is
   written as itself when ADIF allows it for that country, and DX gets
   none. GetStateForContest is deleted with the contest-level answer.
   uTestContestExport.Test_ADIFStateIsTheWorkedStations pins it. *)
function GetADIFStateForQSO(const rec: ContestExchange): string;
begin
   Result := ContestIdentity(rec.ceContest).ADIFWorkedStationState(rec);
end;

const
   (* ADIF 3.1 Primary_Administrative_Subdivision, DXCC 291: the 48
      contiguous states and the District of Columbia. Alaska and Hawaii are
      entities of their own (6 and 110) and are NOT in this list. *)
   ADIF_US_STATES =
      ' AL AR AZ CA CO CT DC DE FL GA IA ID IL IN KS KY LA MA MD ME MI MN' +
      ' MO MS MT NC ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN TX UT VA' +
      ' VT WA WI WV WY ';

   (* DXCC 1: the ten provinces and three territories. *)
   ADIF_CANADIAN_PROVINCES =
      ' AB BC MB NB NL NS NT NU ON PE QC SK YT ';

(* True when aCode is one blank-separated word of aList (which is padded
   with blanks at both ends). *)
function IsCodeInList(const aCode: string; const aList: string): boolean;
begin
   Result := (Length(aCode) = 2) and (Pos(' ' + aCode + ' ', aList) > 0);
end;

function IsADIFPrimarySubdivisionOfDXCC(aDXCC: integer; const aCode: string): boolean;
begin
   case aDXCC of
      291:
         begin
         Result := IsCodeInList(aCode, ADIF_US_STATES);
         end;
      6:
         begin
         Result := aCode = 'AK';
         end;
      110:
         begin
         Result := aCode = 'HI';
         end;
      1:
         begin
         Result := IsCodeInList(aCode, ADIF_CANADIAN_PROVINCES);
         end;
   else
      begin
      Result := False;
      end;
   end;
end;

(* The CTY country is turned into its DXCC code and the DXCC answer is asked --
   'K' is 291, 'KL' 6, 'KH6' 110, 'VE' 1; every other CTY entity, and an
   unknown one (code 0), answers False as before. *)
function IsADIFPrimarySubdivision(const aCountryID, aCode: string): boolean;
begin
   Result := IsADIFPrimarySubdivisionOfDXCC(ADIFDXCCOfCTYEntity(aCountryID), aCode);
end;

function ADIFPartyQTHKey(const aQso: ContestExchange): string;
begin
   Result := Trim(string(aQso.DomesticQTH));
   if Result = '' then
      begin
      Result := Trim(string(aQso.QTHString));
      end;
end;

function ADIFStateOfPartyQSO(const aCountyState: string;
                             const aQso: ContestExchange): string;
var
   code: string;
begin
   if aCountyState <> '' then
      begin
      Result := aCountyState;
      Exit;
      end;

   code := UpperCase(ADIFPartyQTHKey(aQso));
   if IsADIFPrimarySubdivision(string(aQso.QTH.CountryID), code) then
      begin
      Result := code;
      end
   else
      begin
      Result := '';
      end;
end;

function EmitADIFField(const name, value: string): string;
begin
   if value = '' then
      begin
      Result := ''
      end
   else
      begin
      Result := SysUtils.Format('<%s:%u>%s ', [name, Length(value), value]);
      end;
end;

function EmitADIFHeader(const programVersion: string): string;
begin
   Result :=
      EmitADIFField('ADIF_VER', '3.1.0') + #13#10 +
      EmitADIFField('CREATED_TIMESTAMP',
                    FormatDateTime('yyyymmdd hhnnss', Now)) + #13#10 +
      EmitADIFField('PROGRAMID', 'TR4W') + #13#10 +
      EmitADIFField('PROGRAMVERSION', programVersion) + #13#10 +
      '<EOH>'#13#10;
end;

// ----- Per-field helpers used by EmitADIFRecord -----------------------

// Format an integer with at least minLen digits (zero-padded).
function PadInt(n: Integer; minLen: Integer): string;
begin
   Result := IntToStr(n);
   while Length(Result) < minLen do
      begin
      Result := '0' + Result;
      end;
end;

// Determine the (MODE, SUBMODE) ADIF tag pair for a ContestExchange
// based on its ExtMode.  Mirrors the mapping in PostUnit.ExportToADIF
// (the if/else chain on TempRXData.ExtMode).
procedure ResolveADIFModeSubmode(const rec: ContestExchange;
                                  out modeStr, subModeStr: string);
begin
   modeStr := '';
   subModeStr := '';

   if rec.ExtMode = eNoMode then
      begin
      // No extended mode -- use base Mode.  Special case kept from the
      // legacy export: Digital with no ExtMode emits as RTTY (issue 457).
      if rec.Mode = Digital then
         begin
         modeStr := 'RTTY'
         end
      else
         begin
         modeStr := ADIFModeString[rec.Mode];
         end;
      end
   else if rec.ExtMode = eUSB then
      begin
      modeStr    := 'SSB';
      subModeStr := 'USB';
      end
   else if rec.ExtMode = eLSB then
      begin
      modeStr    := 'SSB';
      subModeStr := 'LSB';
      end
   else if rec.ExtMode = ePSK31 then
      begin
      modeStr    := 'PSK';
      subModeStr := ExtendedModeStringArray[rec.ExtMode];
      end
   else if rec.ExtMode = eFT4 then
      begin
      modeStr    := 'MFSK';
      subModeStr := ExtendedModeStringArray[rec.ExtMode];
      end
   else
      begin
      modeStr := ExtendedModeStringArray[rec.ExtMode];
      end;
end;

// Format a frequency (Hz) as an ADIF FREQ string in MHz.  Uses '.'
// as decimal regardless of locale (ADIF spec requires it).
function FormatADIFFreq(freqHz: LongInt): string;
var
   saveSep : Char;
begin
   if freqHz = 0 then
      begin
      Result := '';
      Exit;
      end;
   saveSep := FormatSettings.DecimalSeparator;
   try
      FormatSettings.DecimalSeparator := '.';
      Result := FloatToStr(freqHz / 1000000);
   finally
      FormatSettings.DecimalSeparator := saveSep;
   end;
end;

// Compose a state-QP rover call's bare-and-rover form.  When the
// callsign has a '/<county>' suffix that matches the QSO's QTHString,
// returns (bareCall, fullCall).  Otherwise returns (callsign, '').
procedure ResolveRoverCall(const rec: ContestExchange;
                            out bareCall, roverFullCall: string);
var
   callStr     : string;
   slashPos    : Integer;
   suffix      : string;
begin
   bareCall := string(rec.Callsign);
   roverFullCall := '';
   (* Only the parties that say so -- the class's statement since M10 S8,
      the deleted row's CountyLineAllowed before it (open question Q90). *)
   if not ContestSplitsRoverCallOnExport(rec.ceContest) then
      begin
      Exit;
      end;
   callStr := bareCall;
   slashPos := Pos('/', callStr);
   if slashPos = 0 then
      begin
      Exit;
      end;
   suffix := Copy(callStr, slashPos + 1, Length(callStr) - slashPos);
   if (suffix <> '') and
      (UpperCase(suffix) = UpperCase(string(rec.QTHString))) then
      begin
      roverFullCall := callStr;
      bareCall := Copy(callStr, 1, slashPos - 1);
      end;
end;

// Build the SRX_STRING value with RST normalization -- mirrors the
// commit f048dc7 logic in postunit.pas.
function ExchangeFromSRXString(const aSRX: string;
                               aRSTReceived: integer): string;
var
   prefix: string;
begin
   Result := Trim(aSRX);
   prefix := IntToStr(aRSTReceived) + ' ';
   if Copy(Result, 1, Length(prefix)) = prefix then
      begin
      Result := Trim(Copy(Result, Length(prefix) + 1, Length(Result)));
      end
   (* AN SRX_STRING THAT IS NOTHING BUT THE RST CARRIES NO EXCHANGE, and
     that is ResolveSRXString's own output for an empty ExchString -- see
     its rstStr-only arm. Leaving the '59' in place made the round trip
     grow a token every time: the fourteen GENERAL QSO contacts that
     exchanged no name came back with an exchange of '59' and re-exported
     as '59 59'. *)
   else if Result = IntToStr(aRSTReceived) then
      begin
      Result := '';
      end;
end;

function ResolveSRXString(const rec: ContestExchange): string;
var
   rstStr   : string;
   exch     : string;
   prefix   : string;
begin
   exch := string(rec.ExchString);
   rstStr := IntToStr(rec.RSTReceived);
   prefix := rstStr + ' ';
   if (exch <> '') and (Copy(exch, 1, Length(prefix)) = prefix) then
      begin
      Result := exch
      end
   else if exch = '' then
      begin
      Result := rstStr
      end
   else
      begin
      Result := rstStr + ' ' + exch;
      end;
end;

// ----- EmitADIFRecord -------------------------------------------------

(* THE CONTEST THAT SPEAKS FOR rec: aContest when it is rec's own contest
  (it carries the station), else the identity object. Never the live
  contest -- a QSO of another contest is judged by its own. *)
function ContestForRecord(const rec: ContestExchange;
                          aContest: TContestBase): TContestBase;
begin
   if (aContest <> nil) and
      aContest.IsContestOfQso(rec) then
      begin
      Result := aContest;
      end
   else
      begin
      Result := ContestIdentity(rec.ceContest);
      end;
end;

function EmitADIFRecord(const rec: ContestExchange;
                        aContest: TContestBase): string;
var
   bareCall      : string;
   roverFullCall  : string;
   bandStr        : string;
   modeStr        : string;
   subModeStr     : string;
   freqStr        : string;
   stateForQP     : string;
   rules          : TContestBase;
begin
   rules := ContestForRecord(rec, aContest);
   ResolveRoverCall(rec, bareCall, roverFullCall);

   // BAND string -- mirror the legacy 70cm/23cm rewrites.
   bandStr := string(ADIFBANDSTRINGSARRAY[rec.Band]);
   if bandStr = '432' then
      begin
      bandStr := '70cm';
      end;
   if bandStr = '1GH' then
      begin
      bandStr := '23cm';
      end;

   ResolveADIFModeSubmode(rec, modeStr, subModeStr);
   freqStr := FormatADIFFreq(rec.Frequency);

   Result := '';

   // Identification + timestamps
   Result := Result + EmitADIFField('CALL', bareCall);
   Result := Result + EmitADIFField('BAND', bandStr);
   Result := Result + EmitADIFField('QSO_DATE',
      SysUtils.Format('%.4d%.2d%.2d',
         [rec.tSysTime.qtYear + 2000,
          rec.tSysTime.qtMonth,
          rec.tSysTime.qtDay]));
   Result := Result + EmitADIFField('TIME_ON',
      SysUtils.Format('%.2d%.2d%.2d',
         [rec.tSysTime.qtHour,
          rec.tSysTime.qtMinute,
          rec.tSysTime.qtSecond]));
   Result := Result + EmitADIFField('TIME_OFF',
      SysUtils.Format('%.2d%.2d%.2d',
         [rec.tSysTime.qtHour,
          rec.tSysTime.qtMinute,
          rec.tSysTime.qtSecond]));

   (* The signal report, for every QSO (NY4I, 2026-10-17) -- asked of the
      contest all the same (EmitADIFReportFields), so a class can own a rule. *)
   Result := Result + rules.EmitADIFReportFields(rec);

   // APP_TR4W_ROVERCALL (full rover form, e.g. KG1S/MON)
   if roverFullCall <> '' then
      begin
      Result := Result + EmitADIFField('APP_TR4W_ROVERCALL', roverFullCall);
      end;

   (* CONTEST_ID, unless the contest says it writes none -- General QSO, an
      operating mode, since M4, and POTA, an activation, since it gained its
      class (2026-10-13, design Q6; it was a `ceContest <> POTA` test here).

      THE CONTEST'S OWN ID, ASKED OF THE CONTEST (M1, 2026-10-01). This used to
      spell out "ADIFName, else the enum's spelling" here, one of four copies
      of that rule. The rule is TContestBase.GetADIFContestId now, and import
      (uContestRegistry.FindContestByADIFContestId) matches the same getter,
      so what is written here always reads back to the contest that wrote
      it -- inventory D9, which this closes. *)
   if ContestIdentity(rec.ceContest).WritesADIFContestId then
      begin
      Result := Result + EmitADIFField('CONTEST_ID',
         ContestIdentity(rec.ceContest).ADIFContestId);
      end;

   // MODE / SUBMODE
   Result := Result + EmitADIFField('MODE', modeStr);
   if subModeStr <> '' then
      begin
      Result := Result + EmitADIFField('SUBMODE', subModeStr);
      end;

   // FREQ (locale-independent, '.' separator)
   Result := Result + EmitADIFField('FREQ', freqStr);

   // SRX_STRING is NOT emitted here.  The correct shape depends on the
   // contest's exchange convention (does it include an implied RST?
   // is it a park ref?  is it the literal ExchString?), and that
   // knowledge lives in ExchangeInformation.RST (in trdos/logdupe.pas)
   // which uADIF deliberately does not depend on.  PostUnit's tail
   // emitter (EmitContestSpecificTailForExport) handles SRX_STRING
   // for all contests using ExchangeInformation -- see Issue #898.
   // ResolveSRXString below is exported as a helper for the tail
   // emitter's RST-normalizing branch.

   // STATE - the WORKED station's, and only where the QSO's contest is a
   // QSO party that can say what it is (Q76/Q89, NY4I 2026-10-16): the
   // host's state for a host county, the station's own state or province
   // for an out-of-state QSO when ADIF allows that code for its country,
   // none for DX.  Until then this wrote the HOST's state on every QSO.
   //
   // We deliberately do NOT infer STATE from a bare 2-char QTHString in
   // any other contest.  QTHString means different things per contest (an
   // ARRL section, a zone, a serial, a name, ...), so a "2 letters => it's
   // a state" heuristic mislabels section-based contests -- e.g. ARRL
   // section 'EB' (East Bay) is not the state 'EB'.  A party's QTH IS a
   // county, state or province, which is why only the party classes
   // answer.  Contest-specific STATE that must be derived (e.g. Field Day:
   // section -> state) is emitted by the PostUnit tail emitter.  See
   // Issue #1050.
   stateForQP := GetADIFStateForQSO(rec);
   if (stateForQP <> '') and (rec.QTHString <> '') then
      begin
      Result := Result + EmitADIFField('STATE', stateForQP);
      end;

   (* THE WORKED STATION'S EXCHANGE -- QTH, PRECEDENCE, CHECK, NAME, the
      power tag (RX_PWR, FOC_NUM for the FOC Marathon), SRX, STX, TEN_TEN and
      AGE -- IS THE CONTEST'S TO WRITE (2026-10-17, NY4I: "Shouldn't the uADIF
      exporter be calling the contest class to ask for the specific fields it
      wants to include?"). Each is written only where the contest's own
      ReceivedExchangeFields declares it. This block used to write whichever
      of them was non-empty, so a POTA record carried a PRECEDENCE, a CHECK,
      a TEN_TEN and an AGE that POTA has no such thing as. The unset
      sentinels ($FFFF; -1 on a contest with no serial) are the class's to
      read now: see TContestBase.EmitADIFReceivedFields.
      Contests that prefer GRIDSQUARE/IOTA/ARRL_SECT add them through the
      tail emitter (EmitADIFContestFields). *)
   Result := Result + rules.EmitADIFReceivedFields(rec);

   // OPERATOR + APP_TR4W_ID
   if rec.ceOperator <> '' then
      begin
      Result := Result + EmitADIFField('OPERATOR', string(rec.ceOperator));
      end;
   if rec.id <> '' then
      begin
      Result := Result + EmitADIFField('APP_TR4W_ID', string(rec.id));
      end;

   // APP_TR4W_CLAIMEDQSO (Issue #750).  Mirrors N1MM's
   // APP_N1MM_CLAIMEDQSO convention: '1' = normal QSO, '0' = X-QSO
   // (logged but not claimed for credit -- e.g. an off-band contact
   // kept for NIL protection of the other station).  Only emit for
   // X-QSO records so a grep of the ADIF for CLAIMEDQSO finds exactly
   // the not-claimed contacts; normal QSOs are implied by absence.
   // Lives in uADIF (not the tail emitter) because the value is
   // sourced directly from rec.ceXQSO -- no MainUnit/trdos globals
   // needed -- and because round-trip tests use a nil tail emitter.
   if rec.ceXQSO then
      begin
      Result := Result + EmitADIFField('APP_TR4W_CLAIMEDQSO', '0');
      end;
end;

// ---------------------------------------------------------------------------
// Our station, in and out -- log schema 3, stage 2
// ---------------------------------------------------------------------------

function CTYEntityOfADIFDXCC(aDXCC: integer): AnsiString;
var
   i: integer;
   prefix: string;
   found: integer;
begin
   Result := '';
   if aDXCC <= 0 then
      begin
      Exit;
      end;

   found := 0;
   for i := 0 to DXCCEntityCount - 1 do
      begin
      prefix := DXCCEntityPrefixAt(i);
      if (prefix <> '') and (prefix[1] <> '*') and
         (ADIFDXCCOfCTYEntity(prefix) = aDXCC) then
         begin
         Inc(found);
         (* The prefix is cty.dat's ASCII; the encode states the conversion. *)
         Result := UTF8Encode(prefix);
         end;
      end;

   (* NONE, OR AMBIGUOUS: unknown, never a guess between two entities. *)
   if found <> 1 then
      begin
      Result := '';
      end;
end;

(* A TAG'S TEXT AS THE FACTS HOLD IT: encoded once, exactly, and trimmed.
  The facts are AnsiString and the record's text is UTF-16 here; the RTL's
  Trim, UpperCase and StrToIntDef bind to their AnsiString forms, so every
  step after the encode is conversion-free. *)
function TagText(const aValue: string): AnsiString;
begin
   Result := Trim(UTF8Encode(aValue));
end;

(* The same, upper-cased -- BEFORE the encode, where UpperCase binds to its
  UnicodeString form; after it, it would widen and narrow again. *)
function TagUpper(const aValue: string): AnsiString;
begin
   Result := Trim(UTF8Encode(UpperCase(aValue)));
end;

(* A zone tag: a positive number, else unknown -- 0. *)
function TagZone(const aValue: string): integer;
begin
   Result := StrToIntDef(TagText(aValue), 0);
   if Result < 0 then
      begin
      Result := 0;
      end;
end;

function MyFactsFromADIF(const temps: TADIFRecordTemps): TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := mfsImported;

   Result.Call := TagUpper(temps.MyCall);
   Result.Grid := TagText(temps.MyGridSquare);
   Result.State := TagUpper(temps.MyState);
   Result.County := TagUpper(temps.MyCounty);
   Result.Section := TagUpper(temps.MyARRLSect);
   Result.Iota := TagUpper(temps.MyIOTA);

   (* MY_POTA_REF IS THE PARK; MY_SIG_INFO is one only under MY_SIG POTA --
     under another programme (SOTA, WWFF) it names something else, and is
     not ours to store as a park. *)
   Result.Park := TagUpper(temps.MyPOTARef);
   if (Length(Result.Park) = 0) and SameText(TagText(temps.MySig), 'POTA') then
      begin
      Result.Park := TagUpper(temps.MySigInfo);
      end;

   Result.Country := CTYEntityOfADIFDXCC(TagZone(temps.MyDXCC));
   Result.CQZone := TagZone(temps.MyCQZone);
   Result.ITUZone := TagZone(temps.MyITUZone);
end;

function SentExchangeFromADIF(const temps: TADIFRecordTemps): AnsiString;
begin
   Result := TagText(temps.STX_String);
end;

(* Does aText already carry the tag aName? Case-insensitive, matched on the
  '<NAME:' that opens it, so MY_STATE is not found inside STATE. *)
function ADIFTextHasTag(const aText, aName: string): boolean;
begin
   Result := Pos('<' + UpperCase(aName) + ':', UpperCase(aText)) > 0;
end;

function EmitADIFMyStationFields(const rec: ContestExchange;
                                 const aFacts: TQsoMyFacts;
                                 const aAlreadyWritten: string): string;

   procedure Add(const aName, aValue: string);
   begin
      if (aValue <> '') and (not ADIFTextHasTag(aAlreadyWritten, aName)) and
         (not ADIFTextHasTag(Result, aName)) then
         begin
         Result := Result + EmitADIFField(aName, aValue);
         end;
   end;

   function ZoneValue(aZone: integer): string;
   begin
      Result := '';
      if aZone > 0 then
         begin
         Result := string(IntToStr(aZone));
         end;
   end;

var
   dxcc: integer;
   operatorCall: AnsiString;
begin
   Result := '';
   if aFacts.Source = mfsNotCaptured then
      begin
      Exit;
      end;

   (* THE RULE THE EXPORT HAS ALWAYS APPLIED, asked of the record: the station
     call is written only when somebody other than the station operated it.
     The operator field's own bytes (CharBufferBytes), so the comparison is
     AnsiString against AnsiString. *)
   operatorCall := Trim(CharBufferBytes(rec.ceOperator));
   if (Length(operatorCall) > 0) and (Length(aFacts.Call) > 0) and
      (not SameText(operatorCall, aFacts.Call)) then
      begin
      Add('STATION_CALLSIGN', string(aFacts.Call));
      end;

   Add('MY_GRIDSQUARE', string(aFacts.Grid));
   Add('MY_STATE', string(aFacts.State));
   Add('MY_CNTY', string(aFacts.County));
   Add('MY_ARRL_SECT', string(aFacts.Section));
   Add('MY_IOTA', string(aFacts.Iota));
   Add('MY_CQ_ZONE', ZoneValue(aFacts.CQZone));
   Add('MY_ITU_ZONE', ZoneValue(aFacts.ITUZone));

   dxcc := 0;
   if Length(aFacts.Country) > 0 then
      begin
      dxcc := ADIFDXCCOfCTYEntity(string(aFacts.Country));
      end;
   Add('MY_DXCC', ZoneValue(dxcc));

   (* OUR PARK, LAST. POTA writes these three itself from the record's park,
     before this, so for a POTA QSO all three are skipped; any other contest's
     QSO that recorded a park carries it here, as the import read it. *)
   if Length(aFacts.Park) > 0 then
      begin
      Add('MY_SIG', 'POTA');
      Add('MY_SIG_INFO', string(aFacts.Park));
      Add('MY_POTA_REF', string(aFacts.Park));
      end;
end;

function ExportADIFToString(const records: TContestExchangeArray;
                            const programVersion: string;
                            tailEmitter: TContestTailEmitter;
                            aContest: TContestBase): string;
begin
   Result := ExportADIFToString(records, nil, programVersion, tailEmitter,
                                aContest);
end;

function ExportADIFToString(const records: TContestExchangeArray;
                            const aMyFacts: TQsoMyFactsArray;
                            const programVersion: string;
                            tailEmitter: TContestTailEmitter;
                            aContest: TContestBase): string;
var
   i : Integer;
   facts: TQsoMyFacts;
   body: string;
begin
   Result := EmitADIFHeader(programVersion);
   for i := 0 to High(records) do
      begin
      facts := NotCapturedMyFacts;
      if i <= High(aMyFacts) then
         begin
         facts := aMyFacts[i];
         end;

      body := EmitADIFRecord(records[i], aContest);
      if Assigned(tailEmitter) then
         begin
         body := body + tailEmitter(records[i], facts);
         end;
      (* AFTER THE TAIL, so the contest's own fields win any tag both would
        write, and a never-captured row's line is byte for byte what it was. *)
      body := body + EmitADIFMyStationFields(records[i], facts, body);
      Result := Result + body + '<EOR>'#13#10;
      end;
end;

initialization
   logger := TLogLogger.GetLogger('uADIF');
   saveLastValid    := False;
   saveLastADIFName := '';
   saveLastFound    := False;

end.

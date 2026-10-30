unit uHamScore;
{$I tr4w.inc}

(*
  HamScore Real-Time Contest (RTC) uploader -- Issue #783.

  Sends QSO contact data and dynamicresults score data to hamscore.com
  (Contest Online ScoreBoard) over HTTPS every 2 minutes per the
  RTC v2.3.3-xml specification (June 2024).

  Architecture
  ------------
  - The main thread enqueues lightweight TRTCContact objects via the
    HamScoreOn{Log,Edit,Delete,DeleteLog} entry points.  Each object
    carries its pre-rendered XML body so the main thread holds no live
    references to mutable globals after enqueue and the worker can post
    without taking any TR4W locks.
  - A worker THamScoreUploader thread sleeps on a stop event with a
    120-second timeout.  Every wake builds one POST containing the
    current <dynamicresults> snapshot plus all queued QSO containers,
    POSTs over HTTPS with HTTP Basic Auth (username = the callsign by default),
    and parses the JSON-style status response.
  - Reliability per spec: if the server's reply does not contain
    "Status":"CFM" (or "Status":"OK" for posts with no QSO data) the
    queued contacts STAY queued and are resent on the next 2-minute
    cycle.  Only an explicit CFM clears the pending list.

  Configuration (uCFG.pas)
  ------------------------
    HAMSCORE ENABLE   = TRUE | FALSE   (default FALSE)
    HAMSCORE URL      = https://...    (default hamscore.com)
    HAMSCORE USERNAME = <call>         (empty -> uses MY CALL)
    HAMSCORE PASSWORD = <pw>           (empty disables uploader at start)

  Integration points
  ------------------
    logsubs2.pas:LogContact   -> HamScoreOnLog(RXData, station, sent)
    logsubs2.pas:SendFullLogToHamScore (Tools resync) -> the same, per row
    uEditQSO.pas              -> HamScoreOnEdit(RXData, station, sent)
                                 HamScoreOnDelete(RXData)
    Tools menu                -> HamScoreResyncFromScratch (Phase 3)

  All entry points are cheap no-ops when the uploader is not running.

  Default decisions made without spec guidance, flagged for review:
  - Mode: the QSO's contest's Cabrillo mode column (CabrilloModeString,
    via uCabrillo) -- the file's spelling, so the two cannot drift (Q54)
  - X-QSO records are SENT with <x-qso>1</x-qso>, not skipped
  - No per-contest filtering -- the server returns "Contest not supported"
    for unknown contests; we log and stop trying for the rest of the cycle
  - Both radios share one uploader -- RTC is per-callsign
*)

interface

uses
  (* Windows went with the two raw event handles -- see FWake. *)
  Classes, SysUtils, SyncObjs, uHTTPDownload,
  uConfigValues,   // Config -- the five HAMSCORE settings live here now
  uQsoMyFacts,     // TQsoMyFacts -- a QSO's own station
  VC, Log4D, Version;

type
  TRTCEventKind = (
    rckInfo,         // <contactinfo>    new OR edited QSO (RTC 3.0: same wire
                     //                   format for both; edits use the same
                     //                   QSO ID as the original).
    rckDelete,       // <contactdelete>  deleted QSO
    rckDeleteLog     // <deletelog>      wipe entire log on the server
  );

  // One queue entry. The XML body is rendered at enqueue time on the main
  // thread so the worker can serialise without touching shared globals.
  TRTCContact = class
  public
    Kind:    TRTCEventKind;
    QSOID:   AnsiString;       // RXData.id (TR4W per-QSO GUID); empty for rckDeleteLog
    XmlBody: AnsiString;       // Complete <contactinfo>...</contactinfo> fragment
    constructor Create(AKind: TRTCEventKind; const AQSOID, AXmlBody: AnsiString);
  end;

  THamScoreUploader = class(TThread)
  private
    FQueueLock:    TCriticalSection;
    FPending:      TList;            // FIFO of TRTCContact owned by the uploader
    (* ONE SyncObjs EVENT, WHERE THERE WERE TWO RAW WIN32 HANDLES.

      The note that stood here was correct and is worth keeping, because it
      records a measurement: FPC's TEvent is NOT a kernel object -- it is the
      RTL's own event -- so WaitForSingleObject on TEvent.Handle returns
      WAIT_FAILED with ERROR_INVALID_HANDLE. A THandle() cast would compile
      clean and then never wake, never stop, and never fail visibly. That is
      still true and is still a trap.

      What changed is the REQUIREMENT, not the finding. The raw handles existed
      because the worker blocked in WaitForMultipleObjects on BOTH events at
      once, and a multi-wait needs kernel handles. It does not need two events:
      "stop" and "run a cycle now" are both just "wake up", and what to do on
      waking is answered by TThread.Terminated, which the loop already tests.
      One auto-reset event and the flag the thread already has express exactly
      what the two events did -- including the priority, since Terminated is
      checked before the cycle runs, as WaitForMultipleObjects preferred the
      lower-indexed stop handle.

      So this is not TEvent papering over a multi-wait; the multi-wait is
      gone. *)
    FWake:         TEvent;           { auto-reset: RequestStop and PushNow both signal it }
    FURL:          string;
    FUsername:     string;
    FPassword:     string;
    FCycleMs:      Integer;          // 120000 in production; injectable for tests
    FLogger:       TLogLogger;

    // Status snapshot for the Phase 4 UI window.  Updated from the worker
    // thread inside DoCycle; read by the dialog from the main thread.  All
    // reads/writes go through FQueueLock so we never tear a multi-byte field.
    FLastCycleTime:   TDateTime;     // time the most recent cycle completed
    FLastCycleStatus: string;        // human-readable last-cycle outcome

    function  TakePendingSnapshot: TList;     // moves FPending to a local list, replaces with new empty list
    procedure RestorePending(snapshot: TList); // puts un-CFMed contacts back at the head of FPending
    function  BuildPayload(snapshot: TList; out hadQSOs: Boolean): AnsiString;
    function  PostToServer(const xml: AnsiString; out responseBody: string): Integer;  // returns HTTP status
    function  ResponseStatusKind(const responseBody: string): string;  // 'CFM' | 'OK' | 'Error' | 'ResyncLog' | ''
    procedure DoCycle;
    procedure FreeContactList(list: TList);
    procedure SetCycleStatus(const status: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const AURL, AUsername, APassword: string);
    destructor  Destroy; override;
    procedure   Enqueue(contact: TRTCContact);   // takes ownership
    procedure   RequestStop;
    procedure   PushNow;                         // wake the worker for an immediate cycle

    // Read-only status accessors for the Phase 4 dialog (thread-safe snapshot).
    function    GetPendingCount: Integer;
    function    GetLastCycleStatus: string;
    function    GetLastCycleTime: TDateTime;

    property    URL:      string  read FURL;
    property    Username: string  read FUsername;
    property    CycleMs:  Integer read FCycleMs write FCycleMs;
  end;

// ---------------------------------------------------------------------------
// Module-level configuration (parsed by uCFG via CFGCA entries)
// ---------------------------------------------------------------------------

// The five HAMSCORE settings moved to Config (uConfigValues) when their CFGCA
// rows became csJSON.  Their defaults and types moved with them unchanged; see
// that unit for why the types must match the rows exactly.

// ---------------------------------------------------------------------------
// Lifecycle (called from tr4w.lpr / shutdown path)
// ---------------------------------------------------------------------------

procedure HamScoreInit;       // No-op if Settings.Contest.HamscoreEnable is False or password missing
procedure HamScoreShutdown;   // Safe to call even if Init didn't start the worker

// ---------------------------------------------------------------------------
// QSO event hooks (cheap no-ops when uploader is not running)
// ---------------------------------------------------------------------------

(* THE QSO'S OWN STATION, STATED BY EVERY CALLER (issue 95; NY4I's ruling Q13:
   a logged QSO reads its record, never live state).

   aFacts is our station as the QSO recorded it (my_call and the rest) and
   aRecordedSent its exchange_sent, '' for none -- what the one-QSO Cabrillo
   line says our call and our sent exchange were. A QSO read back from the log
   passes what the log read beside it (LogSourceNext,
   LogSourceReadStationAtIndex). A QSO being logged RIGHT NOW passes
   LogStoreCurrentMyFacts and '': the session is what is being recorded, so the
   two are equal at that moment. There is no overload without them, because a
   caller that does not say gets today's settings -- the defect this fixes. *)
procedure HamScoreOnLog(const RXData: ContestExchange;
                        const aFacts: TQsoMyFacts;
                        const aRecordedSent: AnsiString);
procedure HamScoreOnEdit(const RXData: ContestExchange;
                         const aFacts: TQsoMyFacts;
                         const aRecordedSent: AnsiString);
procedure HamScoreOnDelete(const RXData: ContestExchange);

(* THE SAME THREE HOOKS, SPLIT AT THE THREAD BOUNDARY (2026-10-24).

   Prepare reads live state -- the contest, the settings, the CTY tables -- so
   it runs on the MAIN thread and returns the rendered body ('' = send nothing).
   Submit only appends to the uploader's locked queue, so the QSO dispatcher
   thread may call it. The QSO dispatcher (uQsoDispatcher) carries the body
   between the two; HamScoreOnLog and its siblings are Prepare + Submit in a
   row, for the callers that are not on that path. *)
procedure HamScorePrepareInfo(const RXData: ContestExchange;
                              const aFacts: TQsoMyFacts;
                              const aRecordedSent: AnsiString;
                              out aBody: AnsiString);
procedure HamScorePrepareDelete(const RXData: ContestExchange;
                                out aBody: AnsiString);
procedure HamScoreSubmit(const aDelete: Boolean;
                         const aQSOID: AnsiString;
                         const aBody: AnsiString);

(* IS THE UPLOADER RUNNING? -- so a caller can skip computing the station it
   would hand HamScoreOnLog when nothing would be sent (that capture reads the
   CTY tables). *)
function HamScoreUploaderRunning: Boolean;

// Tools-menu entry point (Phase 3): wipe the server-side log and re-send
// every QSO from the current binary log file.
procedure HamScoreResyncFromScratch;

// WHAT THE STATUS WINDOW SHOWS, as text, in one read.
//
// The window is an LCL form (uHamScoreForm) and asks for this once a second.
// A RECORD rather than six getters because the six fields are one observation:
// read separately, the queue depth can come from a cycle the "last cycle" line
// does not yet mention, and the window shows a state that never existed.
type
   THamScoreStatus = record
      URL:     string;
      User:    string;
      Queue:   string;
      LastRun: string;
      Status:  string;
   end;

function HamScoreStatusSnapshot: THamScoreStatus;

// The Push Now button.  Returns the line to show the operator, so the caller
// does not have to know what the uploader did with the request.
// (The Resync button has no function here: it is MainUnit.
// HamScoreResyncWithConfirmation, because it deletes the server's log and must ask.)
function HamScorePushNow: string;

// The contest id a <deletelog> would carry -- what the resync warning names.
function HamScoreResyncContestId: string;

const
  HAMSCORE_REFRESH_MS = 1000;   // the window's tick -- queue depth moves fast

  // Below this the buttons clip off the bottom and the status field collapses.
  HAMSCORE_MIN_WIDTH  = 410;
  HAMSCORE_MIN_HEIGHT = 270;

implementation

uses
   (* oaScorePosting, the contest's permitted aids. FIRST, so every unit after
      it keeps the meaning it had for any name the two share. *)
   uContestBase,
   uSettingsModel,   // Settings.My.Call
  StrUtils, IdAuthentication,
  LogWind,           // the contest globals this reports
  ZoneCont,          // GetContinentName, ContinentType
  TF,                // CreateButton, CreateStatic
  MainUnit,          // CloseTR4WWindow, DefTR4WProc, FrmSetFocus (impl/impl cycle is OK)
  uGetScores,        // BuildDynamicResultsXml (added by this PR)
  uExchangeBuilder,  // Shared SentExchange / RxExchange canonical builders
  uCabrillo,         // BuildSingleQsoCabrilloLine (RTC 3.0 -- issue #920)
  PostUnit,          // Contest global (RTC 3.0 deletelog needs contest name)
  uContestRegistry;  // ContestIdentity -- the contest's ADIF id

const
  DEFAULT_CYCLE_MS = 120000;   // 2 minutes per RTC spec section 1.2

var
  Uploader: THamScoreUploader = nil;
  ModuleLogger: TLogLogger = nil;

function GetModuleLogger: TLogLogger;
begin
  if ModuleLogger = nil then
     begin
     ModuleLogger := TLogLogger.GetLogger('TR4WDebugLog.HamScore');
     end;
  Result := ModuleLogger;
end;

(* DOES THE OPEN CONTEST ALLOW ITS SCORE TO BE POSTED? -- 2026-10-14.

  THE CONTEST SAYS, AS DATA: TContestBase.PermittedOperatingAids, the same
  answer that greys the post-scores window and its menu row. Until this, the
  RTC uploader asked nothing, so a contest that forbids live score posting
  (WRTC's rule, and IN7QPNE's by NY4I's ruling, design 7.14) was still posted
  here whenever HAMSCORE ENABLE was on. Asked per QSO event and per cycle,
  not once at start-up, because the contest can change while the uploader
  runs. The worker thread asks it too: ContestIdentity is safe from any
  thread, and the cycle already reads the contest globals it reports. *)
function ContestPermitsScorePosting: Boolean;
begin
  Result := oaScorePosting in ContestIdentity(Contest).PermittedOperatingAids;
end;

// ===========================================================================
// XML helpers -- escape and field rendering
// ===========================================================================

function XmlEscape(const s: AnsiString): AnsiString;
var
  i: Integer;
  c: AnsiChar;
begin
  // RTC fields are short identifiers (callsigns, exchanges, mode names).
  // Operator typo could still introduce <, >, &, " or ' -- escape defensively
  // so we don't break the server's XML parser.
  Result := '';
  for i := 1 to Length(s) do
     begin
     c := s[i];
     case c of
       '<': Result := Result + '&lt;';
       '>': Result := Result + '&gt;';
       '&': Result := Result + '&amp;';
       '"': Result := Result + '&quot;';
       '''': Result := Result + '&apos;';
     else
       Result := Result + c;
     end;
     end;
end;

(* THE MODE IS THE CONTEST'S (Q54, NY4I 2026-10-16). MapModeForRTC, this
   unit's own mode map from the RTC 2.4 structured body, had no caller once
   RTC 3.0 sent the QSO as a Cabrillo line, and is deleted: the mode HamScore
   sends is the one uCabrillo.BuildSingleQsoCabrilloLine asks of the QSO's
   contest -- the same CabrilloModeString the Cabrillo file writes. *)

// Map BandType to the MHz integer string the spec lists:
// 1.8, 3.5, 7, 14, 21, 28, 50, 144 (also 10/18/24/...)
function MapBandForRTC(band: BandType): AnsiString;
begin
  case band of
    Band160: Result := '1.8';
    Band80:  Result := '3.5';
    Band40:  Result := '7';
    Band30:  Result := '10';
    Band20:  Result := '14';
    Band17:  Result := '18';
    Band15:  Result := '21';
    Band12:  Result := '24';
    Band10:  Result := '28';
    Band6:   Result := '50';
    Band2:   Result := '144';
  else
    Result := '0';   // unknown / general coverage; server will likely reject
  end;
end;

function CountMultipliers(const RXData: ContestExchange): Integer;
begin
  Result := 0;
  if RXData.DXMult       then
     begin
     Inc(Result);
     end;
  if RXData.DomesticMult then
     begin
     Inc(Result);
     end;
  if RXData.PrefixMult   then
     begin
     Inc(Result);
     end;
  if RXData.ZoneMult     then
     begin
     Inc(Result);
     end;
end;

function FormatTimestamp(const tSysTime: TQSOTime): AnsiString;
begin
  // ISO-style YYYY-MM-DD HH:MM:SS in UTC, matching the BuildUDPContact format.
  Result := AnsiString(Format('20%.2d-%.2d-%.2d %.2d:%.2d:%.2d',
    [tSysTime.qtYear, tSysTime.qtMonth, tSysTime.qtDay,
     tSysTime.qtHour, tSysTime.qtMinute, tSysTime.qtSecond]));
end;

// XML-escaping wrappers around the plain-text shared builders in
// uExchangeBuilder.  Keeping the wrappers thin means LOGSUBS2 (UDP
// broadcast) and uHamScore (RTC POST) emit identical canonical strings.
function BuildSentExchange(const RXData: ContestExchange): AnsiString;
begin
   Result := XmlEscape(AnsiString(BuildSentExchangeText(RXData)));
end;

function BuildRxExchange(const RXData: ContestExchange): AnsiString;
begin
   Result := XmlEscape(AnsiString(BuildRxExchangeText(RXData)));
end;

// Render a <contactinfo> body for one QSO -- RTC 3.0 spec (issue #920).
//
// Replaces the 17-field structured body from the 2.4 protocol with a single
// Cabrillo-format QSO line.  The server's parser is the single source of
// truth for band/mode/exchange interpretation, eliminating the prior need
// for TR4W and the server to agree on every field's canonical form.
//
// Edits use the same <contactinfo> element as new QSOs, just with the same
// QSO ID -- no separate <contactreplace> in 3.0.
function RenderContactBody(AKind: TRTCEventKind; const RXData: ContestExchange;
                           const aFacts: TQsoMyFacts;
                           const aRecordedSent: AnsiString): AnsiString;
var
   cabrillo: AnsiString;
   begin
   if AKind <> rckInfo then
      begin
      Result := '';   // delete / deletelog use other renderers
      Exit;
      end;

   cabrillo := uCabrillo.BuildSingleQsoCabrilloLine(RXData, aFacts, aRecordedSent);

   Result :=
      '<contactinfo>' + sLineBreak +
      #9 + '<ID>' + AnsiString(RXData.id) + '</ID>' + sLineBreak +
      #9 + '<CabrilloString>' + XmlEscape(cabrillo) + '</CabrilloString>' + sLineBreak +
      #9 + '<timestamp>' + FormatTimestamp(RXData.tSysTime) + '</timestamp>' + sLineBreak +
      '</contactinfo>' + sLineBreak;
   end;

function RenderDeleteBody(const QSOID: AnsiString): AnsiString;
begin
  Result :=
    '<contactdelete>' + sLineBreak +
    #9 + '<ID>' + QSOID + '</ID>' + sLineBreak +
    '</contactdelete>' + sLineBreak;
end;

function RenderDeleteLogBody: AnsiString;
var sContest: string;
begin
  // RTC 3.0 (issue #920): <deletelog> now carries a <contest> child so the
  // server can scope the wipe to a single contest if the operator has
  // posted to multiple in the same session.
  (* The contest's ADIF id, asked of the contest -- M1. It is the same id
     BuildDynamicResultsXml sends, from the same getter. *)
  sContest := ContestIdentity(Contest).ADIFContestId;

  Result :=
    '<deletelog>' + sLineBreak +
    #9 + '<contest>' + XmlEscape(AnsiString(sContest)) + '</contest>' + sLineBreak +
    '</deletelog>' + sLineBreak;
end;

// ===========================================================================
// TRTCContact
// ===========================================================================

constructor TRTCContact.Create(AKind: TRTCEventKind; const AQSOID, AXmlBody: AnsiString);
begin
  inherited Create;
  Kind    := AKind;
  QSOID   := AQSOID;
  XmlBody := AXmlBody;
end;

// ===========================================================================
// THamScoreUploader
// ===========================================================================

constructor THamScoreUploader.Create(const AURL, AUsername, APassword: string);
begin
  // Create suspended; caller must Start() us once configured.
  inherited Create(True);
  FreeOnTerminate := False;

  FURL        := AURL;
  FUsername   := AUsername;
  FPassword   := APassword;
  FCycleMs    := DEFAULT_CYCLE_MS;
  FQueueLock  := TCriticalSection.Create;
  FPending    := TList.Create;
  FWake       := TEvent.Create(nil, False, False, '');   { auto-reset, unnamed }
  FLogger     := TLogLogger.GetLogger('TR4WDebugLog.HamScore.Uploader');
  FLastCycleStatus := 'Not yet run';
  FLastCycleTime   := 0;
  FLogger.Info('[HamScore] Created uploader: URL=%s user=%s cycle=%dms',
    [FURL, FUsername, FCycleMs]);
end;

destructor THamScoreUploader.Destroy;
begin
  FreeContactList(FPending);
  FPending.Free;
  FWake.Free;
  FQueueLock.Free;
  inherited;
end;

procedure THamScoreUploader.FreeContactList(list: TList);
var i: Integer;
begin
  if list = nil then Exit;
  for i := 0 to list.Count - 1 do
    if list[i] <> nil then
       begin
       TRTCContact(list[i]).Free;
       end;
  list.Clear;
end;

procedure THamScoreUploader.RequestStop;
begin
  { Terminate sets the flag the worker loop tests; the event only wakes it so
    it does not sit out the rest of its FCycleMs before noticing. }
  Terminate;
  FWake.SetEvent;
end;

procedure THamScoreUploader.PushNow;
begin
  // Manual push from the Phase 4 UI: signal the worker to wake before the
  // 2-minute timer expires.  Auto-reset event so the next post-then-sleep
  // cycle returns to its normal cadence.
  if FWake <> nil then
     begin
     FWake.SetEvent;
     end;
end;

procedure THamScoreUploader.SetCycleStatus(const status: string);
begin
  FQueueLock.Acquire;
  try
    FLastCycleStatus := status;
    FLastCycleTime   := Now;
  finally
    FQueueLock.Release;
  end;
end;

function THamScoreUploader.GetPendingCount: Integer;
begin
  FQueueLock.Acquire;
  try
    Result := FPending.Count;
  finally
    FQueueLock.Release;
  end;
end;

function THamScoreUploader.GetLastCycleStatus: string;
begin
  FQueueLock.Acquire;
  try
    Result := FLastCycleStatus;
  finally
    FQueueLock.Release;
  end;
end;

function THamScoreUploader.GetLastCycleTime: TDateTime;
begin
  FQueueLock.Acquire;
  try
    Result := FLastCycleTime;
  finally
    FQueueLock.Release;
  end;
end;

procedure THamScoreUploader.Enqueue(contact: TRTCContact);
begin
  if contact = nil then Exit;
  FQueueLock.Acquire;
  try
    FPending.Add(contact);
  finally
    FQueueLock.Release;
  end;
end;

// Move all current pending entries to a fresh list and reset FPending.
// Caller owns the returned list; new items enqueued during the cycle land
// in the new FPending and survive a CFM clearing of the in-flight batch.
function THamScoreUploader.TakePendingSnapshot: TList;
var i: Integer;
begin
  Result := TList.Create;
  FQueueLock.Acquire;
  try
    for i := 0 to FPending.Count - 1 do
       begin
       Result.Add(FPending[i]);
       end;
    FPending.Clear;
  finally
    FQueueLock.Release;
  end;
end;

// Put un-CFMed contacts back at the HEAD of FPending so they go out next
// cycle alongside any QSOs enqueued in the meantime.
procedure THamScoreUploader.RestorePending(snapshot: TList);
var
  i: Integer;
  combined: TList;
begin
  if (snapshot = nil) or (snapshot.Count = 0) then
     begin
     snapshot.Free;
     Exit;
     end;

  FQueueLock.Acquire;
  try
    combined := TList.Create;
    try
      for i := 0 to snapshot.Count - 1 do
         begin
         combined.Add(snapshot[i]);
         end;
      for i := 0 to FPending.Count - 1 do
         begin
         combined.Add(FPending[i]);
         end;
      FPending.Clear;
      for i := 0 to combined.Count - 1 do
         begin
         FPending.Add(combined[i]);
         end;
    finally
      combined.Free;
    end;
  finally
    FQueueLock.Release;
  end;
  snapshot.Free;
end;

function THamScoreUploader.BuildPayload(snapshot: TList; out hadQSOs: Boolean): AnsiString;
var
  i:           Integer;
  contact:     TRTCContact;
  dynResults:  AnsiString;
begin
  hadQSOs := (snapshot <> nil) and (snapshot.Count > 0);

  // Build the dynamicresults fragment fresh every cycle (snapshot of current
  // score totals).  Falls back to a minimal shell if uGetScores can't be
  // called -- we still want the post to be valid XML.
  try
    dynResults := uGetScores.BuildDynamicResultsXml;
  except
    on E: Exception do
       begin
       FLogger.Warn('[HamScore] dynamicresults build failed: %s -- sending shell',
         [E.Message]);
       dynResults := '<dynamicresults></dynamicresults>';
       end;
  end;

  // RTC 3.0 (issue #920): wrap the whole post -- <dynamicresults> and any
  // <contactinfo>/<contactdelete>/<deletelog> siblings -- in a single <rtc>
  // outer element.  This is a NEW outer wrapper, not a replacement for
  // <dynamicresults>; both DXLog and N1MM+ produce the same shape.
  Result := '<?xml version="1.0"?>' + sLineBreak +
            '<rtc>' + sLineBreak +
            dynResults + sLineBreak;

  if snapshot <> nil then
     begin
     for i := 0 to snapshot.Count - 1 do
        begin
        contact := TRTCContact(snapshot[i]);
        if contact <> nil then
           begin
           Result := Result + contact.XmlBody;
           end;
        end;
     end;

  Result := Result + '</rtc>' + sLineBreak;
end;

function THamScoreUploader.PostToServer(const xml: AnsiString; out responseBody: string): Integer;
var
  post: THttpPost;
  effectiveUser: string;
begin
  Result := 0;
  responseBody := '';

  // Username defaults to the callsign when HAMSCORE USERNAME is blank.
  if FUsername <> '' then
     begin
     effectiveUser := FUsername
     end
  else
     begin
     effectiveUser := string(Settings.My.Call);
     end;

  (* THE TRANSPORT IS uHTTPDownload'S (2026-09-09), like the other four units
    that each carried their own TIdHTTP and TLS handler. Indy cannot speak to
    OpenSSL 3 -- it finds the library and refuses it -- so a copy of the
    transport in five units meant five places to fix instead of one.

    THE HTTP BASIC CREDENTIALS AND THE Accept-Encoding ARE WHY THttpPost IS AN
    OBJECT rather than another function with nine parameters: this caller needs
    both and the other two need neither. *)
  post := THttpPost.Create(FURL);
  try
    post.Body           := string(xml);
    post.ContentType    := 'application/xml';
    post.UserAgent      := 'TR4W RTC ' + string(TR4W_CURRENTVERSION_NUMBER);
    post.Username       := effectiveUser;
    post.Password       := FPassword;
    post.AcceptEncoding := 'gzip,deflate';
    (* PLAINTEXT IS ALLOWED HERE, DELIBERATELY (2026-10-29). HamScore's own
      recommended address is http://scoredistributor.net/, and the shared
      transport refuses an http:// URL unless the caller says it accepts one,
      so without this every cycle failed with "refused before it began (bad
      URL)" and nothing was ever posted. The URL is the operator's setting, as
      in uGetScores. NOTE THE COST: the Basic credentials above travel in the
      clear on an http:// address. The shared unit logs the URL as plaintext on
      every send. *)
    post.AllowInsecure  := True;

    if FLogger.IsTraceEnabled then
       begin
       FLogger.Trace('[HamScore] POST %s user=%s payload=%s',
          [FURL, effectiveUser, string(xml)]);
       end;

    if post.Send then
       begin
       Result       := post.StatusCode;
       responseBody := post.Response;
       FLogger.Debug('[HamScore] POST %s -> %d, body=%s',
         [FURL, Result, responseBody]);
       end
    else
       begin
       (* ZERO STILL MEANS "no answer", the same as before -- the callers read
         Result as an HTTP status and nothing else. The status is reported
         separately when the server did answer with a refusal, so a 401 no
         longer looks identical to an unreachable host in the log. *)
       FLogger.Warn('[HamScore] POST %s failed: %s (status %d)',
         [FURL, post.FailReason, post.StatusCode]);
       Result := 0;
       end;
  finally
    post.Free;
  end;
end;

// Parse the simple JSON status line.  We don't need a real JSON parser;
// the server's responses are always single-line objects with quoted strings.
function THamScoreUploader.ResponseStatusKind(const responseBody: string): string;
begin
  if Pos('"Status":"CFM"',       responseBody) > 0 then
     begin
     Result := 'CFM'
     end
  else if Pos('"Status":"OK"',         responseBody) > 0 then Result := 'OK'
  else if Pos('"Status":"ResyncLog"',  responseBody) > 0 then Result := 'ResyncLog'
  else if Pos('"Status":"Error"',      responseBody) > 0 then Result := 'Error'
  else
     begin
     Result := '';
     end;
end;

// RTC 3.0 (issue #920): extract the Description field that accompanies
// warnings and errors.  Examples:
//   {"Status":"CFM","Description":"Warning! Exchange error","TimeStamp":"..."}
//   {"Status":"Error","Description":"Bad credentials","TimeStamp":"..."}
// Returns '' when no Description is present (e.g. plain CFM).  Substring
// scan is sufficient because the server always emits single-line JSON
// with no embedded escaped quotes in the Description value.
function ExtractDescription(const responseBody: string): string;
const
   KEY = '"Description":"';
var
   p, q: Integer;
   begin
   Result := '';
   p := Pos(KEY, responseBody);
   if p = 0 then Exit;
   p := p + Length(KEY);
   q := PosEx('"', responseBody, p);
   if q <= p then Exit;
   Result := Copy(responseBody, p, q - p);
   end;

procedure THamScoreUploader.DoCycle;
var
  snapshot:     TList;
  payload:      AnsiString;
  responseBody: string;
  httpCode:     Integer;
  status:       string;
  description:  string;
  hadQSOs:      Boolean;
begin
  (* A CONTEST THAT FORBIDS SCORE POSTING POSTS NOTHING -- not even the
     <dynamicresults> score every cycle carries. Whatever is pending stays
     pending; nothing is queued while such a contest is open. *)
  if not ContestPermitsScorePosting then
     begin
     SetCycleStatus('Score posting is not permitted for this contest');
     Exit;
     end;

  snapshot := TakePendingSnapshot;
  try
    payload := BuildPayload(snapshot, hadQSOs);
    httpCode := PostToServer(payload, responseBody);

    if httpCode = 0 then
       begin
       // Network error -- keep snapshot for next cycle.
       FLogger.Info('[HamScore] Cycle: network error, %d QSO(s) retained for retry',
         [snapshot.Count]);
       SetCycleStatus(Format('Network error -- %d QSO(s) retained', [snapshot.Count]));
       RestorePending(snapshot);
       snapshot := nil;   // ownership transferred
       Exit;
       end;

    if (httpCode < 200) or (httpCode >= 300) then
       begin
       FLogger.Warn('[HamScore] Cycle: HTTP %d, %d QSO(s) retained',
         [httpCode, snapshot.Count]);
       SetCycleStatus(Format('HTTP %d -- %d QSO(s) retained', [httpCode, snapshot.Count]));
       RestorePending(snapshot);
       snapshot := nil;
       Exit;
       end;

    status := ResponseStatusKind(responseBody);
    if (status = 'CFM') or ((status = 'OK') and not hadQSOs) then
       begin
       // RTC 3.0 (issue #920): a CFM may still carry a Description -- the
       // server uses it to signal warnings like "Exchange error" while still
       // accepting the QSO.  Surface it to the operator if present.
       description := ExtractDescription(responseBody);
       FLogger.Info('[HamScore] Cycle CFM (%d QSO(s) confirmed)%s',
         [snapshot.Count,
          IfThen(description <> '', ' -- warning: ' + description, '')]);
       if status = 'CFM' then
         if description <> '' then
            begin
            SetCycleStatus(Format('CFM (warning: %s) -- %d QSO(s) confirmed',
              [description, snapshot.Count]))
            end
         else
            begin
            SetCycleStatus(Format('CFM -- %d QSO(s) confirmed', [snapshot.Count]))
            end
       else
          begin
          SetCycleStatus('OK -- score-only post accepted');
          end;
       // snapshot will be freed in finally -- contacts are released
       Exit;
       end;

    if status = 'ResyncLog' then
       begin
       // Future: trigger a full resync flow.  For now, log and retain so a
       // manual Tools-menu resync remains the operator's escape hatch.
       FLogger.Warn('[HamScore] Server requested ResyncLog -- retaining queue, ' +
         'use Tools menu "Re-send Log to HamScore..." to comply');
       SetCycleStatus('ResyncLog requested -- use Tools menu Re-send Log to HamScore');
       RestorePending(snapshot);
       snapshot := nil;
       Exit;
       end;

    if status = 'Error' then
       begin
       // RTC 3.0 (issue #920): surface the Description rather than the raw
       // JSON envelope when present.
       description := ExtractDescription(responseBody);
       if description <> '' then
          begin
          FLogger.Error('[HamScore] Server error: %s -- retaining %d QSO(s)',
            [description, snapshot.Count]);
          SetCycleStatus('Server error: ' + description);
          end
       else
          begin
          FLogger.Error('[HamScore] Server error: %s -- retaining %d QSO(s)',
            [responseBody, snapshot.Count]);
          SetCycleStatus('Server error: ' + responseBody);
          end;
       RestorePending(snapshot);
       snapshot := nil;
       Exit;
       end;

    // No recognised status (server might be down/proxied).  Keep retrying.
    FLogger.Warn('[HamScore] Unexpected response, retaining %d QSO(s): %s',
      [snapshot.Count, responseBody]);
    SetCycleStatus(Format('Unexpected response -- %d QSO(s) retained', [snapshot.Count]));
    RestorePending(snapshot);
    snapshot := nil;
  finally
    if snapshot <> nil then
       begin
       FreeContactList(snapshot);
       snapshot.Free;
       end;
  end;
end;

procedure THamScoreUploader.Execute;
begin
  FLogger.Info('[HamScore] Worker thread started');
  (* ONE WAIT, AND THE ANSWER IS IN Terminated.

    Was WaitForMultipleObjects on a stop event and a cycle-now event. Both of
    those meant "wake up"; only Terminated says which. Waking early for a push
    and waking on the FCycleMs timeout have always run the same code, so the
    wait result is not examined at all -- if we are still running, run a cycle. *)
  try
    while not Terminated do
       begin
       FWake.WaitFor(Cardinal(FCycleMs));
       if Terminated then Break;
       try
         DoCycle;
       except
         on E: Exception do
            begin
            FLogger.Error('[HamScore] DoCycle exception: %s', [E.Message]);
            SetCycleStatus('Exception: ' + E.Message);
            end;
       end;
       end;
  finally
    FLogger.Info('[HamScore] Worker thread exiting');
  end;
end;

// ===========================================================================
// Module entry points
// ===========================================================================

procedure HamScoreInit;
begin
  if Uploader <> nil then Exit;   // already running
  if not Settings.Contest.HamscoreEnable then Exit;

  if Settings.Hamscore.Password = '' then
     begin
     GetModuleLogger.Warn('[HamScore] HAMSCORE ENABLE = TRUE but HAMSCORE PASSWORD is empty -- uploader not started');
     Exit;
     end;

  if Settings.Hamscore.Url = '' then
     begin
     Settings.Hamscore.Url := 'http://scoredistributor.net/';   // RTC 3.0 default (issue #920)
     end;

  (* PLAIN HTTP IS ALLOWED, AND SAID ONCE. The post carries the password, so a
    plain-http URL sends it unencrypted. Nothing is refused -- both schemes keep
    working -- but the operator who reads the log learns the alternative. The
    URL is logged; the password never is. IsPlainHttpUrl is the same test
    Preferences uses for its note, so the two cannot disagree. *)
  if IsPlainHttpUrl(Settings.Hamscore.Url) then
     begin
     GetModuleLogger.Warn('[HamScore] %s is plain http: the HamScore password is sent unencrypted. '
                          + 'Use https://hamscore.com/postxml/ if the server supports it',
                          [Settings.Hamscore.Url]);
     end;

  Uploader := THamScoreUploader.Create(
    Settings.Hamscore.Url,
    Settings.Hamscore.Username,
    Settings.Hamscore.Password);
  Uploader.Resume;   // Delphi 7 TThread; later Delphis renamed to Start.
  GetModuleLogger.Info('[HamScore] Started');
end;

procedure HamScoreShutdown;
begin
  if Uploader = nil then Exit;
  GetModuleLogger.Info('[HamScore] Shutdown requested');
  Uploader.RequestStop;
  Uploader.WaitFor;
  FreeAndNil(Uploader);
end;

// Issue #931 -- gate per-QSO contact-info uploads on:
//   1. The CFG override (HAMSCORE SEND CONTACT INFO, default TRUE)
//   2. The contest stating itself RTC-capable (its class's RTCCapable)
// <dynamicresults> score posts remain unaffected (handled elsewhere).
function ContactInfoUploadAllowed(const RXData: ContestExchange): Boolean;
   begin
   (* NOTHING IS QUEUED FOR A CONTEST THAT FORBIDS SCORE POSTING. *)
   if not ContestPermitsScorePosting then
      begin
      Result := False;
      Exit;
      end;
   if not Settings.Hamscore.SendContactInfo then
      begin
      Result := False;
      Exit;
      end;
   (* THE QSO'S CONTEST SAYS WHETHER IT TAKES THE UPLOAD (M10 S6) -- it read
      ContestsBooleanArray's RTC_CAPABLE_BIT, which the class's flag set
      states. *)
   Result := ContestIdentity(RXData.ceContest).RTCCapable;
   end;

function HamScoreUploaderRunning: Boolean;
begin
  Result := Uploader <> nil;
end;

procedure HamScorePrepareInfo(const RXData: ContestExchange;
                              const aFacts: TQsoMyFacts;
                              const aRecordedSent: AnsiString;
                              out aBody: AnsiString);
begin
  aBody := '';
  if Uploader = nil then Exit;
  if not ContactInfoUploadAllowed(RXData) then Exit;
  aBody := RenderContactBody(rckInfo, RXData, aFacts, aRecordedSent);
end;

procedure HamScorePrepareDelete(const RXData: ContestExchange;
                                out aBody: AnsiString);
begin
  aBody := '';
  if Uploader = nil then Exit;
  if not ContactInfoUploadAllowed(RXData) then Exit;
  aBody := RenderDeleteBody(AnsiString(RXData.id));
end;

procedure HamScoreSubmit(const aDelete: Boolean;
                         const aQSOID: AnsiString;
                         const aBody: AnsiString);
begin
  (* THREAD-SAFE: Enqueue takes the uploader's queue lock and nothing else.
    The uploader is freed in HamScoreShutdown, which runs AFTER the QSO
    dispatcher has been stopped (ExitProgram). *)
  if Uploader = nil then Exit;
  if aBody = '' then Exit;
  if aDelete then
     begin
     Uploader.Enqueue(TRTCContact.Create(rckDelete, aQSOID, aBody));
     end
  else
     begin
     Uploader.Enqueue(TRTCContact.Create(rckInfo, aQSOID, aBody));
     end;
end;

procedure HamScoreOnLog(const RXData: ContestExchange;
                        const aFacts: TQsoMyFacts;
                        const aRecordedSent: AnsiString);
var body: AnsiString;
begin
  HamScorePrepareInfo(RXData, aFacts, aRecordedSent, body);
  HamScoreSubmit(False, AnsiString(RXData.id), body);
end;

procedure HamScoreOnEdit(const RXData: ContestExchange;
                         const aFacts: TQsoMyFacts;
                         const aRecordedSent: AnsiString);
var body: AnsiString;
begin
  // RTC 3.0 (issue #920): edits use <contactinfo> with the same QSO ID --
  // server distinguishes new vs edit by ID-already-seen.
  HamScorePrepareInfo(RXData, aFacts, aRecordedSent, body);
  HamScoreSubmit(False, AnsiString(RXData.id), body);
end;

procedure HamScoreOnDelete(const RXData: ContestExchange);
var body: AnsiString;
begin
  HamScorePrepareDelete(RXData, body);
  HamScoreSubmit(True, AnsiString(RXData.id), body);
end;

procedure HamScoreResyncFromScratch;
begin
  // Phase 3 -- enqueue the <deletelog> separator.  The full-log walk that
  // re-uploads every QSO lives in LOGSUBS2.SendFullLogToHamScore, which is
  // called by the Tools-menu handler in MainUnit immediately after this.
  if Uploader = nil then Exit;
  if not ContestPermitsScorePosting then
     begin
     Exit;
     end;
  Uploader.Enqueue(TRTCContact.Create(rckDeleteLog, '', RenderDeleteLogBody));
end;

// ===========================================================================
// Phase 4 -- what the status window reads
// ===========================================================================
//
// The dialog procedure, its control-id constants, HamScoreLayoutControls,
// SetTextSafe, SetTextIfChanged and HamScoreRefreshStatus all lived here.  They
// are gone with the window's conversion to an LCL form: anchors replaced the
// hand-written layout, Constraints replaced WM_GETMINMAXINFO, a TTimer replaced
// SetTimer, and TControl.SetCaption already does what SetTextIfChanged did.

function HamScoreStatusSnapshot: THamScoreStatus;
var
  lastTime: TDateTime;
begin
  if Uploader = nil then
     begin
     Result.URL     := 'URL: (uploader not running -- HAMSCORE ENABLE = FALSE or password missing)';
     Result.User    := 'User: --';
     Result.Queue   := '--';
     Result.Status  := 'Disabled';
     Result.LastRun := '';
     Exit;
     end;

  Result.URL   := 'URL: ' + Uploader.URL;
  Result.User  := Uploader.Username;
  if Result.User = '' then
     begin
     Result.User := string(Settings.My.Call) + ' (default; HAMSCORE USERNAME empty)';
     end;
  Result.User := 'User: ' + Result.User;

  Result.Queue  := IntToStr(Uploader.GetPendingCount);
  Result.Status := Uploader.GetLastCycleStatus;

  lastTime := Uploader.GetLastCycleTime;
  if lastTime = 0 then
     begin
     Result.LastRun := 'Last cycle: never';
     end
  else
     begin
     Result.LastRun := 'Last cycle: ' +
                       FormatDateTime('yyyy-mm-dd hh:nn:ss', lastTime);
     end;
end;

function HamScorePushNow: string;
begin
  if Uploader = nil then
     begin
     Result := 'Disabled';
     Exit;
     end;
  Uploader.PushNow;
  Result := 'Push Now signaled -- cycle will run shortly';
end;

function HamScoreResyncContestId: string;
begin
  Result := ContestIdentity(Contest).ADIFContestId;
end;

end.

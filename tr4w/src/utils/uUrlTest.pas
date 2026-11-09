unit uUrlTest;
{$I ..\tr4w.inc}   // relative: this unit lives in src\utils, the include in src
(*
  "WHAT DOES THIS ADDRESS ANSWER?" -- the engine behind the Test button beside a
  URL in Preferences (issue 251).

  NY4I'S RULES, which are the whole design:

     - A 200 is success. Anything else, DISPLAY what came back (the status, or
       the reason there was no answer) and let the operator decide. An error is
       never a verdict on the address: nothing here says "invalid" or "failed".
     - Read-only. One GET, no body, no credentials, never a score or a QSO.
     - The text in the edit box is tested, saved or not. Nothing is saved.
     - Never block the window: the request runs on a worker thread.

  IT USES THE PROGRAM'S OWN HTTP LAYER (uHTTPDownload.THttpRequest), so the test
  meets what a real upload meets: the selected transport, certificate checking
  by the same setting, the same scheme rule. Plain http:// is allowed
  (AllowInsecure), exactly as the score post and the HamScore upload allow it,
  because the operator may have chosen it; the plain-http note on the page stays.
  Redirects are followed and, when the answer came from another address, that
  address is shown beside the status.

  THE WORDING IS OURS, NOT THE LIBRARIES'. A request's FailReason is dialog text
  (and for a refused scheme it says "bad URL"); this unit chooses one short
  sentence per failure kind (UrlTestText, pure and unit-tested) and appends the
  transport's own words in parentheses.

  THE WORKER AND THE FORM: a form can close while a request is in flight. The
  thread never holds the form, a control or the helper. It holds a TICKET, a
  reference-counted result holder shared with whoever started it; when the form
  dies the helper simply drops its reference, and the thread (FreeOnTerminate)
  finishes, fills a ticket nobody reads and goes away. Nothing is joined, so
  closing Preferences never waits on a network.
*)

interface

uses
   Classes, SysUtils, SyncObjs, uHttpTransport;

type
   (* What one test came to. Owned by the ticket that carries it. *)
   TUrlTestOutcome = class
   public
      Url:      string;    (* what was tested, exactly as given *)
      Text:     string;    (* the sentence to show the operator *)
      Answered: boolean;   (* a server replied, whatever the status *)
      Status:   integer;   (* the HTTP status when Answered, else 0 *)
      FinalUrl: string;    (* the address that answered after a redirect, else '' *)
      Success:  boolean;   (* Answered and Status = 200 -- the only success *)
   end;

   (* The result holder shared by the starter and the worker. *)
   IUrlTestTicket = interface
      (* True once the worker has stored its result. *)
      function Finished: boolean;
      (* The result; nil until Finished. Owned by the ticket: use it, do not free it. *)
      function Outcome: TUrlTestOutcome;
   end;

(* THE SENTENCE FOR ONE RESULT, from facts only (pure; no request, no state).

   aAnswered   a server replied (the status is meaningful)
   aStatus     the HTTP status when aAnswered
   aFinalUrl   the address that answered when a redirect was followed, else ''
   aFailure    what went wrong when not aAnswered (hfNone then)
   aDetail     the transport's own words for it, or ''

   Answered:   'Answered 200', or 'Answered 200 from <final address>'.
   Unanswered: 'No answer: <one sentence for the kind>' and, when there are
   any, ' (<the transport's words>)'. *)
function UrlTestText(aAnswered: boolean; aStatus: integer; const aFinalUrl: string;
                     aFailure: THttpFailure; const aDetail: string): string;

(* THE TEST ITSELF, SYNCHRONOUS: one GET of aUrl through the selected transport.
   Never raises. The caller owns the result. An empty aUrl makes no request. *)
function RunUrlTest(const aUrl: string): TUrlTestOutcome;

(* THE TEST ON A WORKER THREAD. Returns at once. The ticket reports Finished
   when the answer is in; whoever started it polls (a timer) and may drop the
   ticket at any time. *)
function StartUrlTest(const aUrl: string): IUrlTestTicket;

implementation

uses
   uHTTPDownload, uAppStrings;

const
   (* A silent server must not hold the operator's attention for long: both are
     shorter than an upload's. WinHTTP rounds a timeout UP to about 4 s. *)
   URL_TEST_CONNECT_MS = 10000;
   URL_TEST_IO_MS      = 15000;
   (* The transport's words are shown in a one-line label with a tooltip. *)
   MAX_DETAIL_CHARS    = 160;

(* One line, no runs of blanks, bounded: a library's message may carry line
  breaks or run on. *)
function TidyDetail(const aDetail: string): string;
begin
   (* UnicodeStringReplace: SysUtils.StringReplace takes AnsiString here and
     would narrow the text (the build counts that). *)
   Result := UnicodeStringReplace(aDetail, #13#10, ' ', [rfReplaceAll]);
   Result := UnicodeStringReplace(Result, #13, ' ', [rfReplaceAll]);
   Result := UnicodeStringReplace(Result, #10, ' ', [rfReplaceAll]);
   Result := Trim(Result);
   if Length(Result) > MAX_DETAIL_CHARS then
      begin
      Result := Copy(Result, 1, MAX_DETAIL_CHARS) + '...';
      end;
end;

(* The sentence for a failure KIND, without the transport's words. A case with
  every member and no default, because a resourcestring cannot sit in a typed
  constant table; uTestUrlTest loops every THttpFailure so a new member that
  gets no sentence here is caught. *)
function NoAnswerSentence(aFailure: THttpFailure): string;
begin
   case aFailure of
      hfBadScheme:
         begin
         Result := SUrlTestNoAnswerScheme;
         end;
      hfPlaintextNotAllowed:
         begin
         Result := SUrlTestNoAnswerPlain;
         end;
      hfTlsUnavailable:
         begin
         Result := SUrlTestNoAnswerTls;
         end;
      hfTlsLibraryFault:
         begin
         Result := SUrlTestNoAnswerTlsLib;
         end;
      hfTrustUnavailable:
         begin
         Result := SUrlTestNoAnswerTrust;
         end;
      hfVerificationUnavailable:
         begin
         Result := SUrlTestNoAnswerVerify;
         end;
      hfVerificationFailed:
         begin
         Result := SUrlTestNoAnswerCert;
         end;
      hfNameNotResolved:
         begin
         Result := SUrlTestNoAnswerName;
         end;
      hfCannotConnect:
         begin
         Result := SUrlTestNoAnswerConnect;
         end;
      hfConnectTimedOut:
         begin
         Result := SUrlTestNoAnswerConnTime;
         end;
      hfIOTimedOut:
         begin
         Result := SUrlTestNoAnswerIoTime;
         end;
      hfConnectionLost:
         begin
         Result := SUrlTestNoAnswerLost;
         end;
      hfCancelled:
         begin
         Result := SUrlTestNoAnswerCancelled;
         end;
      hfNone,
      hfAuthPolicy,
      hfResponseTooLarge,
      hfOther:
         begin
         (* No sentence of our own: the transport's words ARE the answer. *)
         Result := SUrlTestNoAnswerOther;
         end;
   end;
end;

function UrlTestText(aAnswered: boolean; aStatus: integer; const aFinalUrl: string;
                     aFailure: THttpFailure; const aDetail: string): string;
var
   detail: string;
begin
   if aAnswered then
      begin
      if aFinalUrl <> '' then
         begin
         Result := UnicodeFormat(SUrlTestAnsweredFrom, [aStatus, aFinalUrl]);
         end
      else
         begin
         Result := UnicodeFormat(SUrlTestAnswered, [aStatus]);
         end;
      Exit;
      end;

   detail := TidyDetail(aDetail);
   Result := NoAnswerSentence(aFailure);
   if detail <> '' then
      begin
      if Result = SUrlTestNoAnswerOther then
         begin
         (* the words stand in for the sentence *)
         Result := Result + ': ' + detail;
         end
      else
         begin
         Result := Result + ' (' + detail + ')';
         end;
      end;
end;

function RunUrlTest(const aUrl: string): TUrlTestOutcome;
var
   request:  THttpRequest;
   answered: boolean;
begin
   Result     := TUrlTestOutcome.Create;
   Result.Url := aUrl;
   if aUrl = '' then
      begin
      Result.Text := SUrlTestNothing;
      Exit;
      end;

   request := THttpRequest.Create(aUrl);
   try
      (* THttpRequest's defaults are a POST's: say what a read-only probe is.
        No Username, Password or BearerToken -- nothing secret is ever sent. *)
      request.Method          := 'GET';
      request.ContentType     := '';
      request.FollowRedirects := True;
      request.AllowInsecure   := True;
      request.UserAgent       := 'TR4W';
      request.ConnectMs       := URL_TEST_CONNECT_MS;
      request.IOMs            := URL_TEST_IO_MS;
      try
         request.Send;
      except
         on E: Exception do
            begin
            (* Send never raises; this is the belt for the thread's sake. *)
            request.Failure     := hfOther;
            request.ErrorDetail := E.ClassName + ': ' + E.Message;
            end;
      end;

      (* A response too large to keep is still an answer: the server replied. *)
      answered := (request.Failure = hfNone) or
                  ((request.Failure = hfResponseTooLarge) and (request.StatusCode > 0));
      Result.Answered := answered;
      if answered then
         begin
         Result.Status   := request.StatusCode;
         Result.FinalUrl := request.FinalURL;
         Result.Success  := request.StatusCode = 200;
         end;
      Result.Text := UrlTestText(answered, Result.Status, Result.FinalUrl,
                                 request.Failure, request.ErrorDetail);
   finally
      request.Free;
   end;
end;

type
   TUrlTestTicket = class(TInterfacedObject, IUrlTestTicket)
   private
      FLock:     TCriticalSection;
      FFinished: boolean;
      FOutcome:  TUrlTestOutcome;
   public
      constructor Create;
      destructor Destroy; override;
      function Finished: boolean;
      function Outcome: TUrlTestOutcome;
      (* Takes ownership of aOutcome. *)
      procedure Complete(aOutcome: TUrlTestOutcome);
   end;

   TUrlTestThread = class(TThread)
   private
      FUrl:    string;
      (* The reference that keeps the ticket alive for as long as the thread
        runs, whatever the starter does. *)
      FTicket: IUrlTestTicket;
      FTarget: TUrlTestTicket;
   protected
      procedure Execute; override;
   public
      constructor Create(const aUrl: string; aTicket: TUrlTestTicket);
   end;

constructor TUrlTestTicket.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
end;

destructor TUrlTestTicket.Destroy;
begin
   FOutcome.Free;
   FLock.Free;
   inherited Destroy;
end;

function TUrlTestTicket.Finished: boolean;
begin
   FLock.Enter;
   try
      Result := FFinished;
   finally
      FLock.Leave;
   end;
end;

function TUrlTestTicket.Outcome: TUrlTestOutcome;
begin
   FLock.Enter;
   try
      Result := FOutcome;
   finally
      FLock.Leave;
   end;
end;

procedure TUrlTestTicket.Complete(aOutcome: TUrlTestOutcome);
begin
   FLock.Enter;
   try
      FOutcome  := aOutcome;
      FFinished := True;
   finally
      FLock.Leave;
   end;
end;

constructor TUrlTestThread.Create(const aUrl: string; aTicket: TUrlTestTicket);
begin
   inherited Create(True);
   FreeOnTerminate := True;
   FUrl            := aUrl;
   FTarget         := aTicket;
   FTicket         := aTicket;   (* the interface reference: counted *)
end;

procedure TUrlTestThread.Execute;
var
   outcome: TUrlTestOutcome;
begin
   (* RunUrlTest never raises, but a thread that lets one escape ends the
     program, so the last line of defence is here too. *)
   try
      FTarget.Complete(RunUrlTest(FUrl));
   except
      on E: Exception do
         begin
         outcome      := TUrlTestOutcome.Create;
         outcome.Url  := FUrl;
         outcome.Text := UrlTestText(False, 0, '', hfOther, E.ClassName + ': ' + E.Message);
         FTarget.Complete(outcome);
         end;
   end;
end;

function StartUrlTest(const aUrl: string): IUrlTestTicket;
var
   ticket: TUrlTestTicket;
   worker: TUrlTestThread;
begin
   ticket := TUrlTestTicket.Create;
   Result := ticket;   (* the first count; the thread takes a second *)
   worker := TUrlTestThread.Create(aUrl, ticket);
   worker.Start;
end;

end.

unit uExternalLoggerActions;
(* THE DECISIONS BEHIND TWO PER-LOGGER BUTTONS (issue 356, 358), with no
   database, no window and no network in them, so a unit test pins every one.

   1. RESEND QSOs. What is sent again, per delivery row (ResendVerdict).
   2. OPEN SITE. Which address opens, and whether it may (CheckSiteUrl).
   3. THE DEFAULT NAME OF A NEW WRL LOGBOOK (issue 358, WRLDefaultLogbookName).

   RESEND, AND WHY IT CANNOT MAKE A DUPLICATE ON ITS OWN. A delivery row
   (external_delivery) is the memory of what was handed to ONE destination. The
   rules, in the order they apply:

   - No row: the contact was never captured for this destination (it was logged
     while 'Upload active QSOs' was off, or before the logger existed). It is
     CREATED, exactly as a new QSO would have been. Both modes.
   - pending or inflight: already queued or out. Left alone; sending it again
     would race the worker.
   - uncertain: a create or replace may or may not have reached the server.
     NEVER replayed here, in either mode (Club Log's rule, extended to every
     provider): it needs the operator to look at the remote log. Counted so the
     summary can say so.
   - failed with no remote id: the server refused the create, so it is not there.
     Queued again ('not yet delivered' includes it).
   - failed WITH a remote id: an EDIT or DELETE failed on a contact that was
     delivered. Not 'undelivered', so only 'resend all' touches it.
   - synced: delivered. 'Not yet delivered' leaves it. 'Resend all' queues it
     again as an UPDATE of the same remote contact (WRL patches only changed
     fields, Club Log and QRZ replace by remote id), so it replaces rather than
     duplicates, and ONLY for a provider that can update. Cloudlog and ACLog
     cannot (they have no edit call): there it is left alone, because a second
     create would be a second row.

   A 'create' is the one step that can duplicate: if the contact reached the
   destination by some other route (another definition of the same logger, an
   import done by hand) TR4W has no way to know. The confirmation says so. *)
{$I tr4w.inc}

interface

uses
   SysUtils;

type
   TResendMode = (rmUndelivered, rmAll);

   (* What to do with ONE QSO, from its delivery row. *)
   TResendVerdict = (
      rvCreate,        (* no row: capture it as a new contact *)
      rvRequeue,       (* a row to send again (a failed create, or a synced update) *)
      rvQueued,        (* pending or inflight: already on its way *)
      rvUncertain,     (* may be at the destination: never replayed *)
      rvDelivered,     (* delivered, and this mode / provider does not resend it *)
      rvNotOurs,       (* logged by another station: that station uploads it *)
      rvNotDeliverable); (* the QSO cannot become this logger's contact as it stands *)

   (* What a resend did, for the summary the operator reads. A class, not a
      record (the project prefers it); nothing here is shared with a thread. *)
   TResendTally = class
   public
      Created, Requeued, AlreadyQueued, Uncertain, Delivered, NotOurs: integer;
      (* QSOs the payload builder refused (a required field missing). Not in
         Total's other columns' meaning of "left alone": they are marked failed. *)
      NotDeliverable: integer;
      (* The logger had stopped capturing after a storage failure and this
         resend resumed it. *)
      Resumed: boolean;
      (* DXKeeper only: how many of the Requeued were a replace that had already
         deleted the old record, sent as a plain new log. *)
      HalfDone: integer;
      procedure Add(aVerdict: TResendVerdict);
      function Total: integer;
      (* What was put on the queue. *)
      function Queued: integer;
   end;

(* aHasRow False means no delivery row exists for this QSO and destination.
   aState is the row's state text (pending, inflight, synced, uncertain,
   failed); an unknown state is treated as uncertain, the safe reading.
   aHasRemoteId: the row names a remote contact. aCanUpdate: the provider can
   replace a delivered contact. *)
function ResendVerdict(aMode: TResendMode; aHasRow: boolean; const aState: string;
   aHasRemoteId, aCanUpdate: boolean): TResendVerdict;

(* A QSO THAT CANNOT BECOME THIS LOGGER'S CONTACT (issue: a QSO logged with no
   frequency stopped WRL for the whole log). The payload builder raises with a
   message naming the missing field; this maps it to a STABLE code that a
   delivery row can hold, so the Edit QSO window can say why. The message
   itself goes to the log; nothing here reads a secret. *)
function NotDeliverableCode(const aMessage: string): string;

(* The operator's words for one of those codes ('no frequency'); '' for any
   other code, so a caller can tell a not-deliverable row from a refusal. *)
function NotDeliverableReasonText(const aCode: string): string;

(* THE OPERATOR'S WORDS FOR ANY DELIVERY CODE THAT HAS SOME: a QSO the logger
   cannot be given (NotDeliverableReasonText) or a plain-http address that was
   refused (any *_INSECURE_URL_REFUSED, whichever provider's prefix), or one of
   Cloudlog / Wavelog's own codes (CLOUDLOG_HTTP_404 and the rest: the
   sentence says what to change). '' for any other code, so a caller falls
   back to showing the code. *)
function DeliveryFailureReasonText(const aCode: string): string;

(* The same code in a few words, for the narrow Connection column: DXKeeper's
   three codes say 'DXKeeper did not answer ...'; any other code is
   DeliveryFailureReasonText's, '' when it has none. *)
function DeliveryFailureBriefText(const aCode: string): string;

(* Cloudlog's station profile is normally the NUMBER of a station location. True
   when a non-empty value has a character that is not a digit (a name such as
   'Home-EL88'). ADVICE only: the repo holds no evidence that Wavelog refuses a
   name, so the editor shows a note and never refuses the value. *)
function CloudlogProfileLooksWrong(const aValue: string): boolean;

(* A CHOSEN STATION LOCATION AS THE BOX SHOWS IT, AND AS IT IS STORED (NY4I,
  2026-11-24: "keep the number and name in the station field, even though you
  just send the 2"). The box reads '2 - Countryside (NY4I)'; the definition
  stores the NUMBER ('2', what is sent and what the destination is told apart
  by) and the NAME ('Countryside (NY4I)', display only) apart.
  StationChoiceText joins them; SplitStationChoiceText takes a box's text back
  apart: leading digits are the id and the rest, after an optional dash, is the
  name. Text that does not start with a digit is all id (so a typed name still
  reaches the advice note), and a bare number has no name. *)
function StationChoiceText(const aId, aName: string): string;
procedure SplitStationChoiceText(const aText: string; out aId, aName: string);

(* THE NOTICE THROTTLE: one line per logger per window. Ten QSOs held back in a
   row must not scroll ten lines. aLastTick is the tick of the last line shown
   (0 = none yet), aNowTick the current one; both milliseconds. *)
const
   NOT_DELIVERABLE_NOTICE_WINDOW_MS = 60000;

function NotDeliverableNoticeDue(aNowTick, aLastTick: QWord): boolean;

type
   TSiteUrlProblem = (supNone, supEmpty, supScheme, supHost, supCharacters);

(* Whether aUrl may be handed to the operating system's browser. ONLY http and
   https, with a host, no embedded credentials and no whitespace or control
   characters (a file:, javascript:, or custom-scheme address is how a typo
   or a hostile settings file would launch something else). *)
function CheckSiteUrl(const aUrl: string): TSiteUrlProblem;

(* The address a provider's button opens when the definition names none. These
   are PLACEHOLDERS the owner will replace (issue 356). '' for a provider that
   has no web site to open (DXKeeper and ACLog are TCP programs). *)
function DefaultSiteUrl(const aProviderId: string): string;

(* The address the button opens: the definition's own SiteURL, else the
   provider's default, else (Cloudlog / Wavelog, whose address IS the site) the
   address already entered for delivery. '' when there is none. *)
function EffectiveSiteUrl(const aProviderId, aSiteUrl, aAddressField: string): string;

(* 'YYYY CONTEST-ID MODE', the default name of a new WRL logbook (issue 358).
   aYear is the contest's year; aADIFContestId is the contest's ADIF
   CONTEST_ID (ContestIdentity(...).ADIFContestId); aModes are the modes the
   contest is operated in. ONE distinct mode names itself ('CW', 'SSB', 'RTTY');
   none or several give 'MIXED', Cabrillo's CATEGORY-MODE word for it. Blank
   pieces are dropped so the result never has a double space. *)
function WRLDefaultLogbookName(aYear: integer; const aADIFContestId: string;
   const aModes: array of string): string;

implementation

uses
   uriparser, uAppStrings;

procedure TResendTally.Add(aVerdict: TResendVerdict);
begin
   case aVerdict of
      rvCreate:
         begin
         Inc(Created);
         end;
      rvRequeue:
         begin
         Inc(Requeued);
         end;
      rvQueued:
         begin
         Inc(AlreadyQueued);
         end;
      rvUncertain:
         begin
         Inc(Uncertain);
         end;
      rvDelivered:
         begin
         Inc(Delivered);
         end;
      rvNotOurs:
         begin
         Inc(NotOurs);
         end;
      rvNotDeliverable:
         begin
         Inc(NotDeliverable);
         end;
   end;
end;

function TResendTally.Total: integer;
begin
   Result := Created + Requeued + AlreadyQueued + Uncertain + Delivered + NotOurs +
      NotDeliverable;
end;

function TResendTally.Queued: integer;
begin
   Result := Created + Requeued;
end;

function ResendVerdict(aMode: TResendMode; aHasRow: boolean; const aState: string;
   aHasRemoteId, aCanUpdate: boolean): TResendVerdict;
begin
   if not aHasRow then
      begin
      Result := rvCreate;
      Exit;
      end;
   if (aState = 'pending') or (aState = 'inflight') then
      begin
      Result := rvQueued;
      end
   else if aState = 'failed' then
      begin
      if not aHasRemoteId then
         begin
         (* The create was refused: the contact is not at the destination. *)
         Result := rvRequeue;
         end
      else if (aMode = rmAll) and aCanUpdate then
         begin
         Result := rvRequeue;
         end
      else
         begin
         Result := rvDelivered;
         end;
      end
   else if aState = 'synced' then
      begin
      if (aMode = rmAll) and aCanUpdate and aHasRemoteId then
         begin
         Result := rvRequeue;
         end
      else
         begin
         Result := rvDelivered;
         end;
      end
   else
      begin
      (* 'uncertain', and anything this code does not know. *)
      Result := rvUncertain;
      end;
end;

function NotDeliverableCode(const aMessage: string): string;
var
   text: string;
begin
   text := UpperCase(aMessage);
   if Pos('FREQ', text) > 0 then
      begin
      Result := 'MISSING_FREQUENCY';
      end
   else if Pos('ITS MODE', text) > 0 then
      begin
      Result := 'MISSING_MODE';
      end
   else if Pos('DATE/TIME', text) > 0 then
      begin
      Result := 'MISSING_TIME';
      end
   else if Pos('STATION CALLSIGN', text) > 0 then
      begin
      Result := 'MISSING_STATION_CALL';
      end
   else
      begin
      Result := 'QSO_NOT_DELIVERABLE';
      end;
end;

function NotDeliverableReasonText(const aCode: string): string;
begin
   if aCode = 'MISSING_FREQUENCY' then
      begin
      Result := SLoggerWhyNoFrequency;
      end
   else if aCode = 'MISSING_MODE' then
      begin
      Result := SLoggerWhyNoMode;
      end
   else if aCode = 'MISSING_TIME' then
      begin
      Result := SLoggerWhyNoTime;
      end
   else if aCode = 'MISSING_STATION_CALL' then
      begin
      Result := SLoggerWhyNoStationCall;
      end
   else if aCode = 'QSO_NOT_DELIVERABLE' then
      begin
      Result := SLoggerWhyNotDeliverable;
      end
   else
      begin
      Result := '';
      end;
end;

function StationChoiceText(const aId, aName: string): string;
begin
   Result := Trim(aId);
   if (Result <> '') and (Trim(aName) <> '') then
      begin
      Result := Result + ' - ' + Trim(aName);
      end;
end;

procedure SplitStationChoiceText(const aText: string; out aId, aName: string);
var
   text: string;
   i: integer;
begin
   text := Trim(aText);
   i := 1;
   while (i <= Length(text)) and (text[i] in ['0'..'9']) do
      begin
      Inc(i);
      end;
   if (i = 1) or (i > Length(text)) then
      begin
      (* No leading number, or nothing after it: all of it is the id. *)
      aId := text;
      aName := '';
      Exit;
      end;
   aId := Copy(text, 1, i - 1);
   aName := Trim(Copy(text, i, MaxInt));
   if (aName <> '') and (aName[1] = '-') then
      begin
      aName := Trim(Copy(aName, 2, MaxInt));
      end
   else
      begin
      (* '2Countryside' or '2 12': the digits are not an id followed by a name
         (there is no dash), so the whole text stays the id and the advice
         note speaks. *)
      aId := text;
      aName := '';
      end;
end;

function CloudlogProfileLooksWrong(const aValue: string): boolean;
var
   i: integer;
   id, name: string;
begin
   SplitStationChoiceText(aValue, id, name);
   Result := False;
   for i := 1 to Length(id) do
      begin
      if not (id[i] in ['0'..'9']) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* The words for one of uCloudlogClient's codes (prefix CLOUDLOG_), '' for
   any other. HTTP_<n> carries the status in the code. *)
function CloudlogReasonText(const aCode: string): string;
const
   PREFIX = 'CLOUDLOG_';
   HTTP_PREFIX = 'CLOUDLOG_HTTP_';
var
   status: integer;
begin
   Result := '';
   if Copy(aCode, 1, Length(PREFIX)) <> PREFIX then
      begin
      Exit;
      end;
   if Copy(aCode, 1, Length(HTTP_PREFIX)) = HTTP_PREFIX then
      begin
      status := StrToIntDef(UTF8Encode(Copy(aCode, Length(HTTP_PREFIX) + 1, 10)), 0);
      if status = 404 then
         begin
         Result := SLoggerWhyCloudlog404;
         end
      else if status = 401 then
         begin
         Result := SLoggerWhyCloudlog401;
         end
      else if status = 403 then
         begin
         Result := UnicodeFormat(SLoggerWhyCloudlogKey, [status]);
         end
      else if status = 405 then
         begin
         Result := SLoggerWhyCloudlog405;
         end
      else if (status >= 400) and (status < 500) then
         begin
         Result := UnicodeFormat(SLoggerWhyCloudlog4xx, [status]);
         end
      else if status >= 500 then
         begin
         Result := UnicodeFormat(SLoggerWhyCloudlog5xx, [status]);
         end;
      Exit;
      end;
   if aCode = 'CLOUDLOG_UNAUTHORIZED' then
      begin
      Result := SLoggerWhyCloudlog401;
      end
   else if aCode = 'CLOUDLOG_KEY_REJECTED' then
      begin
      Result := SLoggerWhyCloudlogKeyRejected;
      end
   else if aCode = 'CLOUDLOG_STATION_NOT_OWNED' then
      begin
      Result := SLoggerWhyCloudlogStationNotOwned;
      end
   else if aCode = 'CLOUDLOG_CALLSIGN_MISMATCH' then
      begin
      Result := SLoggerWhyCloudlogCallMismatch;
      end
   else if aCode = 'CLOUDLOG_READ_ONLY_KEY' then
      begin
      Result := SLoggerWhyCloudlogReadOnly;
      end
   else if aCode = 'CLOUDLOG_IMPORT_REJECTED' then
      begin
      Result := SLoggerWhyCloudlogRejected;
      end
   else if aCode = 'CLOUDLOG_URL_REFUSED' then
      begin
      Result := SLoggerWhyCloudlogUrl;
      end
   else if aCode = 'CLOUDLOG_REDIRECT' then
      begin
      Result := SLoggerWhyCloudlogRedirect;
      end
   else if aCode = 'CLOUDLOG_SETUP_REQUIRED' then
      begin
      Result := SLoggerWhyCloudlogSetup;
      end
   else if aCode = 'CLOUDLOG_REQUEST_REFUSED' then
      begin
      Result := SLoggerWhyCloudlogBadRequest;
      end
   else if (aCode = 'CLOUDLOG_INVALID_RESPONSE') or
           (aCode = 'CLOUDLOG_RESPONSE_REQUIRES_REVIEW') then
      begin
      Result := SLoggerWhyCloudlogUnreadable;
      end
   else if (aCode = 'CLOUDLOG_EDIT_UNSUPPORTED') or
           (aCode = 'CLOUDLOG_DELETE_UNSUPPORTED') then
      begin
      Result := SLoggerWhyCloudlogNoChange;
      end;
end;

function DXKeeperReasonText(const aCode: string; aBrief: boolean): string;
begin
   Result := '';
   if aCode = 'DXKEEPER_NOT_DELIVERED' then
      begin
      Result := SLoggerWhyDXKeeperNotDelivered;
      end
   else if aCode = 'DXKEEPER_REPLACE_NOT_SENT' then
      begin
      Result := SLoggerWhyDXKeeperReplaceNotSent;
      end
   else if aCode = 'DXKEEPER_REPLACE_HALF_DONE' then
      begin
      Result := SLoggerWhyDXKeeperHalfDone;
      end;
   if aBrief and (Result <> '') then
      begin
      Result := SLoggerWhyDXKeeperBrief;
      end;
end;

function DeliveryFailureBriefText(const aCode: string): string;
begin
   Result := DXKeeperReasonText(aCode, True);
   if Result = '' then
      begin
      Result := DeliveryFailureReasonText(aCode);
      end;
end;

function DeliveryFailureReasonText(const aCode: string): string;
const
   INSECURE_SUFFIX = 'INSECURE_URL_REFUSED';
begin
   Result := NotDeliverableReasonText(aCode);
   if Result = '' then
      begin
      Result := CloudlogReasonText(aCode);
      end;
   if Result = '' then
      begin
      Result := DXKeeperReasonText(aCode, False);
      end;
   if (Result = '') and (Length(aCode) >= Length(INSECURE_SUFFIX)) and
      (Copy(aCode, Length(aCode) - Length(INSECURE_SUFFIX) + 1, Length(INSECURE_SUFFIX)) =
       INSECURE_SUFFIX) then
      begin
      Result := SLoggerWhyInsecure;
      end;
end;

function NotDeliverableNoticeDue(aNowTick, aLastTick: QWord): boolean;
begin
   Result := (aLastTick = 0) or (aNowTick < aLastTick) or
      (aNowTick - aLastTick >= NOT_DELIVERABLE_NOTICE_WINDOW_MS);
end;

function CheckSiteUrl(const aUrl: string): TSiteUrlProblem;
var
   uri: TURI;
   i: integer;
begin
   Result := supNone;
   if Trim(aUrl) = '' then
      begin
      Result := supEmpty;
      Exit;
      end;
   for i := 1 to Length(aUrl) do
      begin
      if (Ord(aUrl[i]) <= 32) or (Ord(aUrl[i]) = 127) then
         begin
         Result := supCharacters;
         Exit;
         end;
      end;
   uri := ParseURI(AnsiString(UTF8Encode(aUrl)));
   if not (SameText(uri.Protocol, 'http') or SameText(uri.Protocol, 'https')) then
      begin
      Result := supScheme;
      Exit;
      end;
   if (uri.Host = '') or (uri.Username <> '') or (uri.Password <> '') then
      begin
      Result := supHost;
      end;
end;

function DefaultSiteUrl(const aProviderId: string): string;
begin
   (* PLACEHOLDERS: the owner supplies the real ones (issue 356). *)
   if aProviderId = 'WRL' then
      begin
      Result := 'https://www.worldradioleague.com';
      end
   else if aProviderId = 'CLUBLOG' then
      begin
      Result := 'https://clublog.org';
      end
   else
      begin
      Result := '';
      end;
end;

function EffectiveSiteUrl(const aProviderId, aSiteUrl, aAddressField: string): string;
begin
   Result := Trim(aSiteUrl);
   if Result = '' then
      begin
      Result := DefaultSiteUrl(aProviderId);
      end;
   if (Result = '') and (aProviderId = 'CLOUDLOG') then
      begin
      Result := Trim(aAddressField);
      end;
end;

function WRLDefaultLogbookName(aYear: integer; const aADIFContestId: string;
   const aModes: array of string): string;
var
   i: integer;
   mode, first: string;
   distinct: integer;
begin
   first := '';
   distinct := 0;
   for i := Low(aModes) to High(aModes) do
      begin
      mode := UpperCase(Trim(aModes[i]));
      if mode = '' then
         begin
         Continue;
         end;
      if distinct = 0 then
         begin
         first := mode;
         distinct := 1;
         end
      else if mode <> first then
         begin
         Inc(distinct);
         end;
      end;
   if distinct = 1 then
      begin
      mode := first;
      end
   else
      begin
      mode := 'MIXED';
      end;
   Result := string(IntToStr(aYear));
   if Trim(aADIFContestId) <> '' then
      begin
      Result := Result + ' ' + Trim(aADIFContestId);
      end;
   Result := Result + ' ' + mode;
end;

end.

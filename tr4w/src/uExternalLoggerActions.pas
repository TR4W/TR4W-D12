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

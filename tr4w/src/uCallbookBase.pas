unit uCallbookBase;
{$I tr4w.inc}

(* CALLBOOK LOOKUP -- THE RESULT AND THE PROVIDER BASE CLASS (issue 321).

   A callbook answers "who holds this callsign": name, grid, state, address,
   licence class, expiry.  Like the radio and external-logger factories, a
   provider is ONE UNIT that subclasses TCallbookProvider and registers itself
   from its initialization section (uCallbookRegistry); nothing shared is edited
   to add one.

   WHAT A SUBCLASS SUPPLIES is the two things that differ between callbooks:
   the request URL, and the reading of the reply.  Everything else -- the
   transport, the timeouts, the logging, the guarantee that a failure becomes a
   Found=False record instead of an exception -- is Lookup, once, here.

   THE TRANSPORT IS uHTTPDownload's HttpGetText, not a second HTTP client.

   Lookup is SYNCHRONOUS and blocks on the network: call it from a worker
   thread.  uCallbookFactory.LookupCallsignAsync is the way to do that. *)

interface

uses
   SysUtils, Log4D;

type
   (* One callbook answer.  EVERY FIELD IS TEXT, exactly as the provider sent it
      (trimmed): latitude and longitude included, because the first provider
      sends them as strings ("28.03") and a caller that wants a number has the
      precision it needs to decide how to convert.  A field the provider did not
      supply is ''.  Found is the only field that says whether the rest mean
      anything: when False every other field is '' except Call, which holds the
      call that was asked for. *)
   TCallbookRecord = class
   public
      Call:         string;
      FirstName:    string;
      LastName:     string;
      Grid:         string;
      Latitude:     string;
      Longitude:    string;
      State:        string;
      Zip:          string;
      Country:      string;
      LicenceClass: string;
      Expires:      string;
      Found:        boolean;
   end;

   (* Delivered on the MAIN thread.  aRec is OWNED BY THE LOOKUP and freed as
      soon as the handler returns: copy what you need, never keep the reference. *)
   TCallbookDoneEvent = procedure(const aRec: TCallbookRecord) of object;

   TCallbookProvider = class
   private
      FId:          string;
      FDisplayName: string;
   protected
      (* The full GET URL for aEncodedCall, which is already percent-encoded. *)
      function RequestUrl(const aEncodedCall: string): string; virtual; abstract;
      (* Reads the reply body into a NEW record the caller frees.  Never raises:
         a body that is not what the provider documents is Found=False. *)
      function ParseReply(const aReply: string): TCallbookRecord; virtual; abstract;
      (* Whether the provider can hold aCall at all (upper-cased, trimmed). A
         call it cannot hold is not sent: Lookup answers Found=False and logs
         aWhy at Info. The default is every call. *)
      function CanHold(const aCall: string; out aWhy: string): boolean; virtual;
   public
      (* Always returns a record the caller frees; never raises and never shows
         anything.  A transport failure and an unknown call both give
         Found=False, and each writes one line to tr4w.log. *)
      function Lookup(const aCall: string): TCallbookRecord;
      (* Set by the registry when it constructs the provider. *)
      property Id:          string read FId          write FId;
      property DisplayName: string read FDisplayName write FDisplayName;
   end;

(* The callsign as one URL path segment: trimmed, upper-cased and percent-encoded,
   so W1AW/4 becomes W1AW%2F4 and cannot add a segment of its own. *)
function EncodeCallbookCall(const aCall: string): string;

(* The callbook's log, a child of the program's own (TR4WDebugLog), so its lines
   reach tr4w.log.  A Log4D logger of its own rather than MainUnit's global:
   that global is set by the program and belongs to a unit that drags in the whole
   UI, which a leaf like this has no business linking (uHTTPDownload does the same). *)
function CallbookLogger: TLogLogger;

implementation

uses
   fphttpclient,    (* EncodeURLElement ONLY -- a pure string function, the one
                       uHTTPDownload already takes for the same purpose *)
   uHTTPDownload;

var
   FLogger: TLogLogger;

const
   (* Short, because the setup wizard waits on this: a callbook that does not
      answer is only a convenience that did not happen. *)
   CALLBOOK_CONNECT_MS = 8000;
   CALLBOOK_IO_MS      = 10000;

function CallbookLogger: TLogLogger;
begin
   Result := FLogger;
end;

function EncodeCallbookCall(const aCall: string): string;
begin
   Result := UTF8Decode(EncodeURLElement(UTF8Encode(UpperCase(Trim(aCall)))));
end;

function TCallbookProvider.CanHold(const aCall: string; out aWhy: string): boolean;
begin
   aWhy   := '';
   Result := True;
end;

function TCallbookProvider.Lookup(const aCall: string): TCallbookRecord;
var
   call:   string;
   url:    string;
   reply:  string;
   why:    string;
begin
   call := UpperCase(Trim(aCall));
   Result := nil;
   try
      if call = '' then
         begin
         Result := TCallbookRecord.Create;
         Exit;
         end;

      (* NOT ASKED: an answer known in advance is not a failed request. The
         transport logs every non-2xx at Error (a 404 for a portable call was
         one), and this is no error. *)
      if not CanHold(call, why) then
         begin
         CallbookLogger.Info('[Callbook] %s not asked about %s: %s', [FId, call, why]);
         Result := TCallbookRecord.Create;
         Result.Call := call;   (* the Exit skips the stamp below *)
         Exit;
         end;

      url := RequestUrl(EncodeCallbookCall(call));
      if not HttpGetText(url, reply, why, 'TR4W', CALLBOOK_CONNECT_MS, CALLBOOK_IO_MS) then
         begin
         CallbookLogger.Warn('[Callbook] %s lookup of %s failed: %s', [FId, call, why]);
         Result := TCallbookRecord.Create;
         end
      else
         begin
         Result := ParseReply(reply);
         if Result.Found then
            begin
            CallbookLogger.Debug('[Callbook] %s lookup of %s found', [FId, call]);
            end
         else
            begin
            CallbookLogger.Info('[Callbook] %s has no record for %s (or the reply was unreadable)',
               [FId, call]);
            end;
         end;
   except
      on E: Exception do
         begin
         CallbookLogger.Error('[Callbook] %s lookup of %s raised %s: %s',
            [FId, call, E.ClassName, E.Message]);
         Result.Free;
         Result := TCallbookRecord.Create;
         end;
   end;

   if not Result.Found then
      begin
      Result.Call := call;
      end;
end;

initialization
   FLogger := TLogLogger.GetLogger('TR4WDebugLog.Callbook');
end.

unit uN1MMLogEnvelope;
{$I tr4w.inc}

(* The N1MM "Log" envelope, framing only (issue 45).

  N1MM Logger+ takes a QSO from JTDX (TCP 52001) and JTAlert / WSJT-X (UDP 2333)
  as

     <command:3>Log<parameters:146><Band:3>20M<Call:5>M4HXM ... <EOR>

  where the number in <parameters:n> is the BYTE length of the ADIF text that
  follows (n1mmwp.hamdocs.com, "Sending log data to N1MM").  This unit turns
  bytes into that ADIF text and nothing else: no socket, no log, no settings,
  no thread, so it is testable without a network and links anywhere.  What
  hands the ADIF to the log (the same path a WSJT-X logged QSO takes,
  uWSJTX.EvaluateLoggedADIF) and the listener that feeds it are separate,
  not-yet-built stages.

  Rules, from the issue and its addendum:
  - the byte count is authoritative: exactly n bytes are the payload;
  - a TCP stream may deliver half an envelope, one, or several in one read, so
    TN1MMLogFramer buffers and hands them back one at a time;
  - a command other than Log is dropped (esIgnored), not an error;
  - one record per envelope: a payload holding more than one <EOR> is refused;
  - tag names are case-insensitive; the payload is UTF-8 (ASCII is the same);
  - receive-only: nothing here, or in the stages above it, answers the sender;
  - bounded: a name, a length field and the payload have ceilings, so a hostile
    or confused sender cannot make the buffer grow without limit. *)

interface

type
   TN1MMEnvelopeStatus = (
      esNeedMore,    (* the envelope is not all here yet; nothing consumed *)
      esLog,         (* a Log envelope: the ADIF text is in aAdif *)
      esIgnored,     (* well-formed, but not the Log command: consumed *)
      esMalformed);  (* refused; aWhy says why *)

const
   N1MM_LOG_MAX_PAYLOAD = 65536;       (* bytes of ADIF in one envelope *)
   N1MM_LOG_MAX_BUFFER = 131072;       (* bytes a framer will hold unparsed *)

(* Read ONE envelope from aBuf starting at byte aPos (1-based).
  esLog / esIgnored: aPos moves past the envelope.
  esNeedMore: aPos is unchanged; call again when more bytes have arrived.
  esMalformed: the framing is lost, so aPos moves to the end of aBuf (a stream
  cannot be resynchronised), EXCEPT for a well-framed envelope whose payload
  is refused (more than one record), where only that envelope is consumed.
  aWhy is set for esIgnored and esMalformed. *)
function N1MMReadEnvelope(const aBuf: RawByteString; var aPos: integer;
                          out aAdif: string;
                          out aWhy: string): TN1MMEnvelopeStatus;

(* One UDP datagram is one whole envelope.  True with the ADIF text in aAdif;
  False with the reason in aWhy (truncated, malformed, not the Log command, or
  bytes after the envelope).  Trailing CR/LF/blank is allowed. *)
function N1MMParseDatagram(const aData: RawByteString; out aAdif: string;
                           out aWhy: string): Boolean;

type
   (* One per TCP connection: Feed what recv returned, then call Next until it
     answers esNeedMore. *)
   TN1MMLogFramer = class
   private
      FBuf: RawByteString;
      FPos: integer;
   public
      constructor Create;
      (* False when the unparsed bytes would pass N1MM_LOG_MAX_BUFFER: the
        buffer is emptied and the caller should drop the connection. *)
      function Feed(const aBytes: RawByteString): Boolean;
      function Next(out aAdif: string; out aWhy: string): TN1MMEnvelopeStatus;
      function PendingBytes: integer;
   end;

implementation

uses
   SysUtils;

const
   MAX_TAG_NAME = 32;
   MAX_LENGTH_DIGITS = 6;
   MAX_TYPE_FIELD = 16;

type
   TTagResult = (trOk, trNeedMore, trBad);

(* One <name:length>value tag from aPos.  Leading blanks, CR, LF and NUL are
  skipped (a sender may end each envelope with a line break).  aPos moves only
  on trOk. *)
function ReadTag(const aBuf: RawByteString; var aPos: integer;
                 out aName: string; out aValue: RawByteString;
                 out aWhy: string): TTagResult;
var
   p: integer;
   q: integer;
   len: integer;
   n: integer;
   digits: integer;
   count: integer;
begin
   aName := '';
   aValue := '';
   aWhy := '';
   len := Length(aBuf);
   p := aPos;
   while (p <= len) and (aBuf[p] in [#0, #9, #10, #13, ' ']) do
      begin
      Inc(p);
      end;
   if p > len then
      begin
      Result := trNeedMore;
      Exit;
      end;
   if aBuf[p] <> '<' then
      begin
      aWhy := 'expected "<" at the start of a tag';
      Result := trBad;
      Exit;
      end;
   Inc(p);

   q := p;
   while (q <= len) and (q - p <= MAX_TAG_NAME) and
         (aBuf[q] <> ':') and (aBuf[q] <> '>') do
      begin
      Inc(q);
      end;
   if q - p > MAX_TAG_NAME then
      begin
      aWhy := 'tag name is too long';
      Result := trBad;
      Exit;
      end;
   if q > len then
      begin
      Result := trNeedMore;
      Exit;
      end;
   if aBuf[q] = '>' then
      begin
      aWhy := 'tag has no length';
      Result := trBad;
      Exit;
      end;
   aName := UnicodeLowerCase(UnicodeString(Copy(aBuf, p, q - p)));

   Inc(q);
   n := 0;
   digits := 0;
   while (q <= len) and (aBuf[q] in ['0'..'9']) and
         (digits <= MAX_LENGTH_DIGITS) do
      begin
      n := n * 10 + (Ord(aBuf[q]) - Ord('0'));
      Inc(digits);
      Inc(q);
      end;
   if digits > MAX_LENGTH_DIGITS then
      begin
      aWhy := 'tag length has too many digits';
      Result := trBad;
      Exit;
      end;
   if q > len then
      begin
      Result := trNeedMore;
      Exit;
      end;
   if digits = 0 then
      begin
      aWhy := 'tag length is not a number';
      Result := trBad;
      Exit;
      end;

   if aBuf[q] = ':' then
      begin
      (* An ADIF data-type indicator, <name:length:type>: skip it. *)
      Inc(q);
      count := 0;
      while (q <= len) and (aBuf[q] <> '>') and (count <= MAX_TYPE_FIELD) do
         begin
         Inc(q);
         Inc(count);
         end;
      if q > len then
         begin
         Result := trNeedMore;
         Exit;
         end;
      end;
   if aBuf[q] <> '>' then
      begin
      aWhy := 'tag is not closed by ">"';
      Result := trBad;
      Exit;
      end;
   Inc(q);

   if n > N1MM_LOG_MAX_PAYLOAD then
      begin
      aWhy := 'tag length exceeds the limit';
      Result := trBad;
      Exit;
      end;
   if q + n - 1 > len then
      begin
      Result := trNeedMore;
      Exit;
      end;
   aValue := Copy(aBuf, q, n);
   aPos := q + n;
   Result := trOk;
end;

(* HOW MANY <EOR> MARKERS THE PAYLOAD HOLDS, reading it as ADIF: a field's value
  is exactly its stated number of bytes and is SKIPPED, so a comment or a name
  that happens to contain the text "<eor>" is not a record end (review of issue
  45: searching the whole text for it made a valid record malformed). The walk
  is over the raw bytes because the lengths are byte counts. Text between tags
  is ignored; a tag that does not close ends the walk. *)
function CountEndOfRecords(const aPayload: RawByteString): integer;
var
   len: integer;
   p: integer;
   q: integer;
   n: integer;
   name: string;
begin
   Result := 0;
   len := Length(aPayload);
   p := 1;
   while p <= len do
      begin
      if aPayload[p] <> '<' then
         begin
         Inc(p);
         Continue;
         end;
      q := p + 1;
      while (q <= len) and (aPayload[q] <> ':') and (aPayload[q] <> '>') do
         begin
         Inc(q);
         end;
      if q > len then
         begin
         Exit;
         end;
      name := LowerCase(string(Copy(aPayload, p + 1, q - p - 1)));
      if aPayload[q] = '>' then
         begin
         if name = 'eor' then
            begin
            Inc(Result);
            end;
         p := q + 1;
         Continue;
         end;
      (* <name:length> or <name:length:type> -- the value follows the '>'. *)
      Inc(q);
      n := 0;
      while (q <= len) and (aPayload[q] in ['0'..'9']) and (n < N1MM_LOG_MAX_PAYLOAD) do
         begin
         n := n * 10 + (Ord(aPayload[q]) - Ord('0'));
         Inc(q);
         end;
      while (q <= len) and (aPayload[q] <> '>') do
         begin
         Inc(q);
         end;
      if q > len then
         begin
         Exit;
         end;
      p := q + 1 + n;
      end;
end;

function N1MMReadEnvelope(const aBuf: RawByteString; var aPos: integer;
                          out aAdif: string;
                          out aWhy: string): TN1MMEnvelopeStatus;
var
   p: integer;
   name: string;
   command: RawByteString;
   payload: RawByteString;
   r: TTagResult;
   isLog: Boolean;
begin
   aAdif := '';
   aWhy := '';
   p := aPos;

   r := ReadTag(aBuf, p, name, command, aWhy);
   if r = trNeedMore then
      begin
      Result := esNeedMore;
      Exit;
      end;
   if r = trBad then
      begin
      aPos := Length(aBuf) + 1;
      Result := esMalformed;
      Exit;
      end;
   if name <> 'command' then
      begin
      aWhy := 'expected <command>, found <' + name + '>';
      aPos := Length(aBuf) + 1;
      Result := esMalformed;
      Exit;
      end;
   isLog := UnicodeSameText(UnicodeString(command), 'Log');

   r := ReadTag(aBuf, p, name, payload, aWhy);
   if r = trNeedMore then
      begin
      Result := esNeedMore;
      Exit;
      end;
   if r = trBad then
      begin
      aPos := Length(aBuf) + 1;
      Result := esMalformed;
      Exit;
      end;
   if name <> 'parameters' then
      begin
      aWhy := 'expected <parameters>, found <' + name + '>';
      aPos := Length(aBuf) + 1;
      Result := esMalformed;
      Exit;
      end;

   (* The envelope is whole and well framed from here: a refusal consumes just
     this envelope and the stream stays in step. *)
   aPos := p;
   if not isLog then
      begin
      aWhy := 'command is not Log: ' + UnicodeString(Copy(command, 1, 20));
      Result := esIgnored;
      Exit;
      end;
   if payload = '' then
      begin
      aWhy := 'the Log envelope carries no ADIF';
      Result := esMalformed;
      Exit;
      end;

   if CountEndOfRecords(payload) > 1 then
      begin
      aWhy := 'more than one record in one envelope';
      Result := esMalformed;
      Exit;
      end;
   aAdif := UTF8Decode(payload);
   Result := esLog;
end;

function N1MMParseDatagram(const aData: RawByteString; out aAdif: string;
                           out aWhy: string): Boolean;
var
   p: integer;
   status: TN1MMEnvelopeStatus;
begin
   p := 1;
   status := N1MMReadEnvelope(aData, p, aAdif, aWhy);
   if status = esNeedMore then
      begin
      aWhy := 'truncated datagram';
      Result := False;
      Exit;
      end;
   if status <> esLog then
      begin
      Result := False;
      Exit;
      end;
   while (p <= Length(aData)) and (aData[p] in [#0, #9, #10, #13, ' ']) do
      begin
      Inc(p);
      end;
   if p <= Length(aData) then
      begin
      aAdif := '';
      aWhy := 'bytes after the envelope';
      Result := False;
      Exit;
      end;
   Result := True;
end;

constructor TN1MMLogFramer.Create;
begin
   inherited Create;
   FBuf := '';
   FPos := 1;
end;

function TN1MMLogFramer.Feed(const aBytes: RawByteString): Boolean;
begin
   if FPos > 1 then
      begin
      Delete(FBuf, 1, FPos - 1);
      FPos := 1;
      end;
   if Length(FBuf) + Length(aBytes) > N1MM_LOG_MAX_BUFFER then
      begin
      FBuf := '';
      Result := False;
      Exit;
      end;
   FBuf := FBuf + aBytes;
   Result := True;
end;

function TN1MMLogFramer.Next(out aAdif: string;
                             out aWhy: string): TN1MMEnvelopeStatus;
begin
   Result := N1MMReadEnvelope(FBuf, FPos, aAdif, aWhy);
end;

function TN1MMLogFramer.PendingBytes: integer;
begin
   Result := Length(FBuf) - FPos + 1;
end;

end.

unit uMessageText;

(* THE GRAMMAR OF A PROGRAM MESSAGE -- brace words (NY4I, 2026-11-20).

  A program message (a CQ or exchange function-key memory, or one of the
  "other" message templates) is keyed character by character, and most
  characters are either plain text or one of the CRYPTIC characters the CW
  sender knows ('\' my call, '#' the serial, '@' his call, '{' the worked
  call, '}' the partial call, ...). This unit does not interpret those: they
  are TEXT here and LogSend.SendCrypticCWString keys them exactly as before,
  including '#'s look-ahead ('#+1') and the Ctrl-[ command escape, which is
  why they are not split into parts of their own.

  NY4I's RULE: '{' STANDS FOR <03> AND '}' FOR <04> -- nothing more.

     {BODY}     BODY is any text but a brace, at least one character, and it
                is run exactly as <03>BODY<04> runs: {SPEED+}, {ALT-D},
                {SRS=PB1;}, {OTRSP=RX1}. The command NAME (the body up to
                its first '=') is matched in any case; the rest is kept as
                written.
     {$BODY}    the same command on the INACTIVE radio -- the job of the
                Ctrl-A byte in <03><01>BODY<04>.

  A body is a TOKEN (ROVERCALL, ROVERQTH -- keyed in place by the CW sender),
  a COMMAND (a name the command table registers, which is the lookup the old
  bookend used, plus QSY and SPEED followed by digits or by '+'/'-' -- the
  two FoundCommand answers outside its table), or UNKNOWN.

  A '{' WITH NO BODY IS STILL THE CRYPTIC '{' -- the worked call -- exactly
  as before: '{}', a '{' with no closing brace, and the first '{' of '{{X}}'
  (another '{' comes before any '}'; the second starts the body X).

  THE OLD FORM, <03>BODY<04> (Ctrl-C ... Ctrl-D), still works: it is a part
  of its own (mpOldCommand), run verbatim. UpgradeMessageBookends rewrites it
  to the brace form, a leading Ctrl-A becoming '$'. A Ctrl-D with no Ctrl-C
  before it is the CHAIN marker (LogSend keys a space while CW is still going
  out) and is never touched.

  A LEAF: SysUtils, Classes and Contnrs only, AnsiString throughout because a
  message is a ShortString of bytes and an index into it must stay a byte
  index. The command names are REGISTERED here by uProcessCommand (which
  cannot be linked into a leaf), so the grammar has one home. *)

{$I tr4w.inc}

interface

uses
   Classes,
   Contnrs;

const
   (* The two TOKENS -- keyed in place by the CW sender. *)
   MESSAGE_TOKEN_ROVERCALL = 'ROVERCALL';
   MESSAGE_TOKEN_ROVERQTH = 'ROVERQTH';
   (* The network pass tokens, N1MM's spellings (issue 71, NY4I 2026-11-22):
     {PASS NAME} and {PASS 14000} (the argument follows a SPACE, not '=', and
     is kept in aArgument) and {LASTPASSEDFREQ}. Keyed in place, like the
     rover tokens -- uNetPass expands them. *)
   MESSAGE_TOKEN_PASS = 'PASS';
   MESSAGE_TOKEN_LASTPASSEDFREQ = 'LASTPASSEDFREQ';

   (* The old bookends, and the old inactive-radio byte. *)
   MESSAGE_OLD_COMMAND_START = #3;
   MESSAGE_OLD_COMMAND_END = #4;
   MESSAGE_OLD_INACTIVE_RADIO = #1;

   (* The brace form's inactive-radio mark, first in the body. *)
   MESSAGE_INACTIVE_RADIO_MARK = '$';

type
   TMessageWordKind = (mwNone, mwToken, mwCommand, mwUnknown);

   TMessagePartKind = (mpText, mpToken, mpCommand, mpUnknownWord, mpOldCommand);

   (* ONE PART OF A PARSED MESSAGE. Text is always the part AS WRITTEN, so the
     parts joined are the message.
     mpText        literal text, cryptic characters included
     mpToken       Name: ROVERCALL or ROVERQTH
     mpCommand     Name (upper case, without '$'), Argument (as written,
                   after the first '='), HasArgument, InactiveRadio ('$');
                   CommandLine: what FoundCommand runs
     mpUnknownWord Name (upper case, without '$'); Body: as written
     mpOldCommand  CommandLine: the body between Ctrl-C and Ctrl-D, verbatim *)
   TMessagePart = class
   public
      Kind: TMessagePartKind;
      Text: AnsiString;
      Body: AnsiString;
      Name: AnsiString;
      Argument: AnsiString;
      HasArgument: boolean;
      InactiveRadio: boolean;
      CommandLine: AnsiString;
   end;

(* A COMMAND NAME the command table answers to. Registered once, by
  uProcessCommand's initialization; any row may be registered, since a
  display row (it starts with a space) can never be the name of a body. *)
procedure RegisterMessageCommandWord(const aName: AnsiString);

(* WHAT A BRACE BODY IS. aBody is the text between the braces, as written;
  the out parameters describe it whatever its kind. *)
function MessageBodyKind(const aBody: AnsiString;
                         out aName, aArgument: AnsiString;
                         out aHasArgument, aInactiveRadio: boolean): TMessageWordKind;

(* IS THERE A BRACE WORD AT aText[aIndex]? mwNone when there is not -- the
  '{' is the cryptic worked call, or aIndex is not a '{' at all. Otherwise
  aName (upper case, without '$'), aArgument, aHasArgument and aLength (from
  '{' to '}' inclusive) describe it. *)
function MessageWordAt(const aText: AnsiString; aIndex: integer;
                       out aName, aArgument: AnsiString;
                       out aHasArgument: boolean;
                       out aLength: integer): TMessageWordKind;

(* aText IN PARTS, in order, into aParts (emptied first; it owns them). *)
procedure ParseMessage(const aText: AnsiString; aParts: TObjectList);

(* THE FIRST UNKNOWN BRACE WORD in aText, as written between the braces; ''
  when every word is known. A message that names one is refused at save. *)
function FirstUnknownMessageWord(const aText: AnsiString): AnsiString;

(* SHOULD A FUNCTION-KEY MESSAGE LEAVE THE CW THAT IS GOING OUT ALONE? True
  when aText holds a Ctrl-D (a chain marker, or an old command's end -- the
  test LogCW's caller always made) or a brace COMMAND: a command message has
  never flushed the CW in progress. A token or an unknown word does not
  count. *)
function MessageChainsOrCommands(const aText: AnsiString): boolean;

(* THE OLD BOOKENDS REWRITTEN: every Ctrl-C BODY Ctrl-D whose body names a
  known COMMAND becomes {BODY} -- {$BODY} for a leading Ctrl-A -- the body
  as written. Byte for byte, so the length never changes. aLeftAlone counts
  the pairs that stay as they were: a body naming no command (a typo, which
  the old form ran as nothing and still does), or one holding a brace or
  another control character. A Ctrl-C with no Ctrl-D after it, and a lone
  Ctrl-D, are not pairs and are not counted. *)
function UpgradeMessageBookends(const aText: AnsiString;
                                out aConverted, aLeftAlone: integer): AnsiString;

(* WHAT THE COMMAND PICKER INSERTS for aInsertable (the picker row's own
  token): {aInsertable} when it names a registered command, with or without
  an argument; otherwise aInsertable itself -- a cryptic character, a
  display row. *)
function MessagePickerText(const aInsertable: AnsiString): AnsiString;

implementation

uses
   SysUtils;

var
   GCommandWords: TStringList;

procedure RegisterMessageCommandWord(const aName: AnsiString);
begin
   if aName <> '' then
      begin
      GCommandWords.Add(UpperCase(aName));
      end;
end;

(* SPEED25, SPEED+, SPEED-- : FoundCommand's SPEED arm takes digits, or a
  run of '+' then '-', after the name. *)
function IsSpeedCommand(const aName: AnsiString): boolean;
var
   i: integer;
   digits, steps: boolean;
begin
   Result := (Length(aName) > 5) and (Copy(aName, 1, 5) = 'SPEED');
   if not Result then
      begin
      Exit;
      end;
   digits := True;
   steps := True;
   for i := 6 to Length(aName) do
      begin
      if (aName[i] < '0') or (aName[i] > '9') then
         begin
         digits := False;
         end;
      if (aName[i] <> '+') and (aName[i] <> '-') then
         begin
         steps := False;
         end;
      end;
   Result := digits or steps;
end;

function MessageBodyKind(const aBody: AnsiString;
                         out aName, aArgument: AnsiString;
                         out aHasArgument, aInactiveRadio: boolean): TMessageWordKind;
var
   body: AnsiString;
   eqAt: integer;
begin
   aName := '';
   aArgument := '';
   aHasArgument := False;
   aInactiveRadio := False;
   Result := mwUnknown;

   body := aBody;
   if Copy(body, 1, 1) = MESSAGE_INACTIVE_RADIO_MARK then
      begin
      aInactiveRadio := True;
      Delete(body, 1, 1);
      end;

   (* {PASS NAME}: the word PASS, a space, then what it names. A bare {PASS}
     is not a token (it names nothing) and falls through to unknown. *)
   if (not aInactiveRadio) and (Length(body) > 5) and
      (UpperCase(Copy(body, 1, 5)) = MESSAGE_TOKEN_PASS + ' ') and
      (Trim(Copy(body, 6, Length(body))) <> '') then
      begin
      aName := MESSAGE_TOKEN_PASS;
      aArgument := Trim(Copy(body, 6, Length(body)));
      aHasArgument := True;
      Result := mwToken;
      Exit;
      end;

   if (not aInactiveRadio) and (UpperCase(body) = MESSAGE_TOKEN_LASTPASSEDFREQ) then
      begin
      aName := MESSAGE_TOKEN_LASTPASSEDFREQ;
      Result := mwToken;
      Exit;
      end;

   eqAt := Pos('=', body);
   if eqAt > 0 then
      begin
      aHasArgument := True;
      aArgument := Copy(body, eqAt + 1, Length(body) - eqAt);
      aName := UpperCase(Copy(body, 1, eqAt - 1));
      end
   else
      begin
      aName := UpperCase(body);
      end;

   if aName = '' then
      begin
      Exit;
      end;

   if (aName = MESSAGE_TOKEN_ROVERCALL) or (aName = MESSAGE_TOKEN_ROVERQTH) then
      begin
      if (not aHasArgument) and (not aInactiveRadio) then
         begin
         Result := mwToken;
         end;
      Exit;
      end;

   (* QSY and SPEED: FoundCommand answers them outside its table. *)
   if (GCommandWords.IndexOf(aName) >= 0) or
      (aName = 'QSY')                      or
      ((not aHasArgument) and IsSpeedCommand(aName)) then
      begin
      Result := mwCommand;
      end;
end;

(* THE BODY OF A BRACE WORD at aText[aIndex]: the text up to the FIRST '}',
  which must hold at least one character and no '{'. False when there is
  none -- the '{' is the cryptic worked call. *)
function ScanBraceBody(const aText: AnsiString; aIndex: integer;
                       out aBody: AnsiString; out aLength: integer): boolean;
var
   i: integer;
   closeAt: integer;
begin
   Result := False;
   aBody := '';
   aLength := 0;

   if (aIndex < 1) or (aIndex > Length(aText)) or (aText[aIndex] <> '{') then
      begin
      Exit;
      end;

   closeAt := 0;
   for i := aIndex + 1 to Length(aText) do
      begin
      if aText[i] = '}' then
         begin
         closeAt := i;
         Break;
         end;
      if aText[i] = '{' then
         begin
         Exit;
         end;
      end;
   if closeAt <= aIndex + 1 then
      begin
      Exit;
      end;

   aBody := Copy(aText, aIndex + 1, closeAt - aIndex - 1);
   aLength := closeAt - aIndex + 1;
   Result := True;
end;

function MessageWordAt(const aText: AnsiString; aIndex: integer;
                       out aName, aArgument: AnsiString;
                       out aHasArgument: boolean;
                       out aLength: integer): TMessageWordKind;
var
   body: AnsiString;
   inactiveRadio: boolean;
begin
   Result := mwNone;
   aName := '';
   aArgument := '';
   aHasArgument := False;
   if not ScanBraceBody(aText, aIndex, body, aLength) then
      begin
      Exit;
      end;
   Result := MessageBodyKind(body, aName, aArgument, aHasArgument, inactiveRadio);
end;

procedure ParseMessage(const aText: AnsiString; aParts: TObjectList);
var
   i: integer;
   endAt: integer;
   text: AnsiString;
   body: AnsiString;
   wordLength: integer;
   kind: TMessageWordKind;
   part: TMessagePart;

   procedure FlushText;
   begin
      if text = '' then
         begin
         Exit;
         end;
      part := TMessagePart.Create;
      part.Kind := mpText;
      part.Text := text;
      aParts.Add(part);
      text := '';
   end;

begin
   aParts.Clear;
   text := '';
   i := 1;
   while i <= Length(aText) do
      begin
      if aText[i] = MESSAGE_OLD_COMMAND_START then
         begin
         endAt := Pos(MESSAGE_OLD_COMMAND_END, Copy(aText, i + 1, Length(aText)));
         if endAt > 0 then
            begin
            FlushText;
            part := TMessagePart.Create;
            part.Kind := mpOldCommand;
            part.Text := Copy(aText, i, endAt + 1);
            part.Body := Copy(aText, i + 1, endAt - 1);
            part.CommandLine := part.Body;
            aParts.Add(part);
            i := i + endAt + 1;
            Continue;
            end;
         end;

      if ScanBraceBody(aText, i, body, wordLength) then
         begin
         FlushText;
         part := TMessagePart.Create;
         kind := MessageBodyKind(body, part.Name, part.Argument,
                                 part.HasArgument, part.InactiveRadio);
         case kind of
            mwToken:
               begin
               part.Kind := mpToken;
               end;
            mwCommand:
               begin
               part.Kind := mpCommand;
               (* As <03>BODY<04> would run: the name upper-cased so any
                 case matches, '$' back to the Ctrl-A it stands for. *)
               part.CommandLine := part.Name;
               if part.HasArgument then
                  begin
                  part.CommandLine := part.CommandLine + '=' + part.Argument;
                  end;
               if part.InactiveRadio then
                  begin
                  part.CommandLine := MESSAGE_OLD_INACTIVE_RADIO + part.CommandLine;
                  end;
               end;
         else
            begin
            part.Kind := mpUnknownWord;
            end;
         end;
         part.Text := Copy(aText, i, wordLength);
         part.Body := body;
         aParts.Add(part);
         i := i + wordLength;
         Continue;
         end;

      text := text + aText[i];
      Inc(i);
      end;
   FlushText;
end;

function FirstUnknownMessageWord(const aText: AnsiString): AnsiString;
var
   parts: TObjectList;
   i: integer;
   part: TMessagePart;
begin
   Result := '';
   parts := TObjectList.Create(True);
   try
      ParseMessage(aText, parts);
      for i := 0 to parts.Count - 1 do
         begin
         part := TMessagePart(parts[i]);
         if part.Kind = mpUnknownWord then
            begin
            Result := part.Body;
            Exit;
            end;
         end;
   finally
      parts.Free;
   end;
end;

function MessageChainsOrCommands(const aText: AnsiString): boolean;
var
   parts: TObjectList;
   i: integer;
begin
   Result := Pos(MESSAGE_OLD_COMMAND_END, aText) > 0;
   if Result then
      begin
      Exit;
      end;
   parts := TObjectList.Create(True);
   try
      ParseMessage(aText, parts);
      for i := 0 to parts.Count - 1 do
         begin
         if TMessagePart(parts[i]).Kind = mpCommand then
            begin
            Result := True;
            Exit;
            end;
         end;
   finally
      parts.Free;
   end;
end;

(* A BRACE BODY MAY HOLD NEITHER A BRACE NOR A CONTROL CHARACTER, or it
  would not read back as the same command. *)
function BodyFitsInBraces(const aBody: AnsiString): boolean;
var
   i: integer;
begin
   Result := aBody <> '';
   for i := 1 to Length(aBody) do
      begin
      if (aBody[i] < ' ') or (aBody[i] = '{') or (aBody[i] = '}') then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

function UpgradeMessageBookends(const aText: AnsiString;
                                out aConverted, aLeftAlone: integer): AnsiString;
var
   parts: TObjectList;
   i: integer;
   part: TMessagePart;
   body: AnsiString;
   name, argument: AnsiString;
   hasArgument, inactiveRadio: boolean;
begin
   aConverted := 0;
   aLeftAlone := 0;
   Result := '';
   parts := TObjectList.Create(True);
   try
      ParseMessage(aText, parts);
      for i := 0 to parts.Count - 1 do
         begin
         part := TMessagePart(parts[i]);
         if part.Kind <> mpOldCommand then
            begin
            Result := Result + part.Text;
            Continue;
            end;

         body := part.Body;
         if Copy(body, 1, 1) = MESSAGE_OLD_INACTIVE_RADIO then
            begin
            body := MESSAGE_INACTIVE_RADIO_MARK + Copy(body, 2, Length(body) - 1);
            end;

         if BodyFitsInBraces(body) and
            (MessageBodyKind(body, name, argument, hasArgument, inactiveRadio) = mwCommand) then
            begin
            Result := Result + '{' + body + '}';
            Inc(aConverted);
            end
         else
            begin
            Result := Result + part.Text;
            Inc(aLeftAlone);
            end;
         end;
   finally
      parts.Free;
   end;
end;

function MessagePickerText(const aInsertable: AnsiString): AnsiString;
var
   name, argument: AnsiString;
   hasArgument, inactiveRadio: boolean;
begin
   Result := aInsertable;
   if not BodyFitsInBraces(aInsertable) then
      begin
      Exit;
      end;
   if MessageBodyKind(aInsertable, name, argument, hasArgument, inactiveRadio) = mwCommand then
      begin
      Result := '{' + aInsertable + '}';
      end;
end;

initialization
   GCommandWords := TStringList.Create;
   GCommandWords.Sorted := True;
   GCommandWords.Duplicates := dupIgnore;
   GCommandWords.CaseSensitive := True;

finalization
   FreeAndNil(GCommandWords);

end.

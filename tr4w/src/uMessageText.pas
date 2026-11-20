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

  WHAT THIS UNIT OWNS is the one thing that is not a single character -- a
  NAMED WORD, written in braces:

     {NAME}          NAME is letters, digits and '_' (at least one), in any
                     case; matched case-insensitively
     {NAME=ARGUMENT} for a command that takes one (SRS=PB1;, OTRSP=RX1,
                     SPAN=50, SENDTOCLUSTER=...). The argument is any
                     printable characters but '{' and '}', kept AS WRITTEN

  A word is a TOKEN (ROVERCALL, ROVERQTH -- keyed in place), a COMMAND (a name
  the command table registers, plus QSY and SPEEDnn, which
  uProcessCommand.FoundCommand handles outside its table), or UNKNOWN.

  A '{' THAT DOES NOT START SUCH A WORD IS STILL THE CRYPTIC '{' -- the worked
  call -- exactly as before: '{ TU', '{}', '{{X}}' (a '{', then the word X),
  a '{' with no closing brace.

  THE OLD FORM, <03>COMMAND<04> (Ctrl-C ... Ctrl-D), still works: it is a
  part of its own (mpOldCommand). UpgradeMessageBookends rewrites it to the
  brace form where the body IS a brace word; a body that is not one (an
  inactive-radio Ctrl-A prefix, SPEED+, ALT-D) is left as it was. A Ctrl-D
  with no Ctrl-C before it is the CHAIN marker (LogSend keys a space while CW
  is still going out) and is never touched.

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

   (* The old bookends. *)
   MESSAGE_OLD_COMMAND_START = #3;
   MESSAGE_OLD_COMMAND_END = #4;

type
   TMessageWordKind = (mwNone, mwToken, mwCommand, mwUnknown);

   TMessagePartKind = (mpText, mpToken, mpCommand, mpUnknownWord, mpOldCommand);

   (* ONE PART OF A PARSED MESSAGE.
     mpText        Text: literal text, cryptic characters included
     mpToken       Name: ROVERCALL or ROVERQTH; Text: the word as written
     mpCommand     Name (upper case) and Argument; HasArgument when '=' was
                   written; Text: the word as written
     mpUnknownWord Name (upper case); Text: the word as written
     mpOldCommand  Text: the body between Ctrl-C and Ctrl-D, as written *)
   TMessagePart = class
   public
      Kind: TMessagePartKind;
      Text: AnsiString;
      Name: AnsiString;
      Argument: AnsiString;
      HasArgument: boolean;
   end;

(* A COMMAND NAME the command table answers to. Registered once, by
  uProcessCommand's initialization; a name that is not a brace word ('ALT-D',
  a display row) is ignored. *)
procedure RegisterMessageCommandWord(const aName: AnsiString);

(* WHAT aName (any case) IS. aHasArgument: an '=' was written -- a token
  takes none, so ROVERCALL=X is unknown. *)
function MessageWordKind(const aName: AnsiString; aHasArgument: boolean): TMessageWordKind;

(* IS THERE A BRACE WORD AT aText[aIndex]? mwNone when there is not -- the
  '{' is the cryptic worked call, or aIndex is not a '{' at all. Otherwise
  aName (upper case), aArgument, aHasArgument and aLength (from '{' to '}'
  inclusive) describe it. *)
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

(* THE OLD BOOKENDS REWRITTEN: every Ctrl-C BODY Ctrl-D whose body is a brace
  word (NAME or NAME=ARGUMENT) naming a known COMMAND becomes {BODY}, the
  body as written. Two bytes for two bytes, so the length never changes.
  aLeftAlone counts the pairs that stay as they were -- a body that is no
  brace word (a Ctrl-A inactive-radio prefix, SPEED+, ALT-D) or names no
  command (a typo, which the old form ran as nothing and still does); a
  Ctrl-C with no Ctrl-D after it, and a lone Ctrl-D, are not pairs and are
  not counted. *)
function UpgradeMessageBookends(const aText: AnsiString;
                                out aConverted, aLeftAlone: integer): AnsiString;

(* WHAT THE COMMAND PICKER INSERTS for aInsertable (the picker row's own
  token): {aInsertable} when it is a registered command, with or without an
  argument; otherwise aInsertable itself -- a cryptic character, a display
  row, ALT-D. *)
function MessagePickerText(const aInsertable: AnsiString): AnsiString;

implementation

uses
   SysUtils;

var
   GCommandWords: TStringList;

function IsWordChar(c: AnsiChar): boolean;
begin
   Result := ((c >= 'A') and (c <= 'Z')) or
             ((c >= 'a') and (c <= 'z')) or
             ((c >= '0') and (c <= '9')) or
             (c = '_');
end;

function IsArgumentChar(c: AnsiChar): boolean;
begin
   Result := (c >= ' ') and (c <> '{') and (c <> '}') and (c <> #127);
end;

(* IS aBody, the text between two braces, a word? NAME, or NAME=ARGUMENT. *)
function SplitWordBody(const aBody: AnsiString;
                       out aName, aArgument: AnsiString;
                       out aHasArgument: boolean): boolean;
var
   i: integer;
   nameEnd: integer;
begin
   Result := False;
   aName := '';
   aArgument := '';
   aHasArgument := False;

   nameEnd := 0;
   for i := 1 to Length(aBody) do
      begin
      if not IsWordChar(aBody[i]) then
         begin
         Break;
         end;
      nameEnd := i;
      end;

   if nameEnd = 0 then
      begin
      Exit;
      end;

   if nameEnd < Length(aBody) then
      begin
      if aBody[nameEnd + 1] <> '=' then
         begin
         Exit;
         end;
      for i := nameEnd + 2 to Length(aBody) do
         begin
         if not IsArgumentChar(aBody[i]) then
            begin
            Exit;
            end;
         end;
      aHasArgument := True;
      aArgument := Copy(aBody, nameEnd + 2, Length(aBody) - nameEnd - 1);
      end;

   aName := UpperCase(Copy(aBody, 1, nameEnd));
   Result := True;
end;

procedure RegisterMessageCommandWord(const aName: AnsiString);
var
   name, argument: AnsiString;
   hasArgument: boolean;
begin
   if not SplitWordBody(aName, name, argument, hasArgument) then
      begin
      Exit;
      end;
   if hasArgument then
      begin
      Exit;
      end;
   if GCommandWords.IndexOf(name) < 0 then
      begin
      GCommandWords.Add(name);
      end;
end;

(* SPEED25, SPEED5 -- FoundCommand's SPEED arm takes digits after the name. *)
function IsSpeedWord(const aName: AnsiString): boolean;
var
   i: integer;
begin
   Result := (Length(aName) > 5) and (Copy(aName, 1, 5) = 'SPEED');
   if not Result then
      begin
      Exit;
      end;
   for i := 6 to Length(aName) do
      begin
      if (aName[i] < '0') or (aName[i] > '9') then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

function MessageWordKind(const aName: AnsiString; aHasArgument: boolean): TMessageWordKind;
var
   name: AnsiString;
begin
   name := UpperCase(aName);

   if (name = MESSAGE_TOKEN_ROVERCALL) or (name = MESSAGE_TOKEN_ROVERQTH) then
      begin
      if aHasArgument then
         begin
         Result := mwUnknown;
         end
      else
         begin
         Result := mwToken;
         end;
      Exit;
      end;

   (* QSY and SPEEDnn: FoundCommand answers them outside its table. *)
   if (GCommandWords.IndexOf(name) >= 0) or
      (name = 'QSY')                     or
      ((not aHasArgument) and IsSpeedWord(name)) then
      begin
      Result := mwCommand;
      Exit;
      end;

   Result := mwUnknown;
end;

function MessageWordAt(const aText: AnsiString; aIndex: integer;
                       out aName, aArgument: AnsiString;
                       out aHasArgument: boolean;
                       out aLength: integer): TMessageWordKind;
var
   i: integer;
   closeAt: integer;
begin
   Result := mwNone;
   aName := '';
   aArgument := '';
   aHasArgument := False;
   aLength := 0;

   if (aIndex < 1) or (aIndex > Length(aText)) or (aText[aIndex] <> '{') then
      begin
      Exit;
      end;

   (* The FIRST '}' after the '{'. A '{' before it means this '{' starts no
     word -- '{{X}}' is a cryptic '{' and then the word X. *)
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
   if closeAt = 0 then
      begin
      Exit;
      end;

   if not SplitWordBody(Copy(aText, aIndex + 1, closeAt - aIndex - 1),
                        aName, aArgument, aHasArgument) then
      begin
      Exit;
      end;

   aLength := closeAt - aIndex + 1;
   Result := MessageWordKind(aName, aHasArgument);
end;

procedure ParseMessage(const aText: AnsiString; aParts: TObjectList);
var
   i: integer;
   endAt: integer;
   text: AnsiString;
   name, argument: AnsiString;
   hasArgument: boolean;
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
            part.Text := Copy(aText, i + 1, endAt - 1);
            aParts.Add(part);
            i := i + endAt + 1;
            Continue;
            end;
         end;

      if aText[i] = '{' then
         begin
         kind := MessageWordAt(aText, i, name, argument, hasArgument, wordLength);
         if kind <> mwNone then
            begin
            FlushText;
            part := TMessagePart.Create;
            case kind of
               mwToken:
                  begin
                  part.Kind := mpToken;
                  end;
               mwCommand:
                  begin
                  part.Kind := mpCommand;
                  end;
            else
               begin
               part.Kind := mpUnknownWord;
               end;
            end;
            part.Text := Copy(aText, i, wordLength);
            part.Name := name;
            part.Argument := argument;
            part.HasArgument := hasArgument;
            aParts.Add(part);
            i := i + wordLength;
            Continue;
            end;
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
            (* As written, between the braces. *)
            Result := Copy(part.Text, 2, Length(part.Text) - 2);
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

function UpgradeMessageBookends(const aText: AnsiString;
                                out aConverted, aLeftAlone: integer): AnsiString;
var
   parts: TObjectList;
   i: integer;
   part: TMessagePart;
   name, argument: AnsiString;
   hasArgument: boolean;
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
            (* Everything else as written -- a part's Text is its spelling. *)
            Result := Result + part.Text;
            Continue;
            end;

         if SplitWordBody(part.Text, name, argument, hasArgument) and
            (MessageWordKind(name, hasArgument) = mwCommand) then
            begin
            Result := Result + '{' + part.Text + '}';
            Inc(aConverted);
            end
         else
            begin
            Result := Result + MESSAGE_OLD_COMMAND_START + part.Text +
                      MESSAGE_OLD_COMMAND_END;
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
   hasArgument: boolean;
begin
   Result := aInsertable;
   if not SplitWordBody(aInsertable, name, argument, hasArgument) then
      begin
      Exit;
      end;
   if GCommandWords.IndexOf(name) >= 0 then
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

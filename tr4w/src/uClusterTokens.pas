unit uClusterTokens;

// EXPANDING THE BRACED TOKENS IN A CLUSTER COMMAND.
//
// A LEAF, deliberately.  This lived in uTelnet, which pulls in the socket, the
// spot model and the dialog procedure, so none of it could be linked by the
// unit tests -- and the expander is a small parser with real edge cases
// (doubled braces, an unterminated brace, an unknown token) that ought to be
// pinned rather than eyeballed against a live cluster.
//
// THE VOCABULARY DOES NOT LIVE HERE.  Naming a token is one job; knowing that
// MY_CALL means the MyCall global is another, and that second job needs the
// application's state.  So the caller supplies a lookup function and this unit
// stays linkable on its own.  That split is not just for the tests: it is what
// lets the same parser serve the send path and the preview.
//
// WHY SEGMENTS RATHER THAN A STRING.  The preview shows the operator what will
// actually go out, and the useful part of that is seeing WHICH text was
// substituted -- so the result records each run of text with a flag, and the
// caller decides how to distinguish them (italics, colour, or not at all).
// Callers that only want the finished text ask SegmentsToText.

{$I tr4w.inc}

interface

type
   // Returns True and sets Value when Token is one this application knows.
   // Token arrives already normalized.  An unknown token must return False,
   // NOT an empty string -- the parser leaves unknown tokens verbatim so a
   // typo is visible to the operator instead of silently deleting itself.
   TClusterTokenLookup = function(const Token: string; out Value: string): boolean;

   TClusterSegment = record
      Text: string;
      // True when this run REPLACED a braced token.  Literal text, an unknown
      // token left verbatim, and an escaped brace are all False.
      Substituted: boolean;
   end;

   TClusterSegments = array of TClusterSegment;

// Trims surrounding spaces and upper-cases A..Z, so token matching tolerates
// spacing and case.
function NormalizeClusterToken(const S: string): string;

// Expands every braced token in Src.  Pure -- no global state is read or
// written here -- so it is safe on the send path and the hover preview alike.
function ExpandClusterSegments(const Src: string;
                               Lookup: TClusterTokenLookup): TClusterSegments;

// The finished command text, segments concatenated.
function SegmentsToText(const Segments: TClusterSegments): string;

implementation

function NormalizeClusterToken(const S: string): string;
var
   i, First, Last: integer;
   c: Char;
begin
   First := 1;
   Last := Length(S);

   while (First <= Last) and (S[First] = ' ') do
      begin
      Inc(First);
      end;

   while (Last >= First) and (S[Last] = ' ') do
      begin
      Dec(Last);
      end;

   Result := '';

   for i := First to Last do
      begin
      c := S[i];

      if (c >= 'a') and (c <= 'z') then
         begin
         c := Char(Ord(c) - 32);
         end;

      Result := Result + c;
      end;
end;

// Appends to the LAST segment when the flag matches, so literal text never
// fragments into one segment per character.
procedure AppendSegment(var Segments: TClusterSegments;
                        const Text: string;
                        const Substituted: boolean);
var
   Last: integer;
begin
   if Text = '' then
      begin
      Exit;
      end;

   Last := Length(Segments) - 1;

   if (Last >= 0) and (Segments[Last].Substituted = Substituted) then
      begin
      Segments[Last].Text := Segments[Last].Text + Text;
      Exit;
      end;

   SetLength(Segments, Last + 2);
   Segments[Last + 1].Text := Text;
   Segments[Last + 1].Substituted := Substituted;
end;

function ExpandClusterSegments(const Src: string;
                               Lookup: TClusterTokenLookup): TClusterSegments;
var
   Token, Value: string;
   i, Len, j: integer;
   Found: boolean;
begin
   Result := nil;
   Len := Length(Src);
   i := 1;

   while i <= Len do
      begin
      if (Src[i] = '{') and (i < Len) and (Src[i + 1] = '{') then
         begin
         // An escaped brace is literal text, not a substitution.
         AppendSegment(Result, '{', False);
         Inc(i, 2);
         end
      else if (Src[i] = '}') and (i < Len) and (Src[i + 1] = '}') then
         begin
         AppendSegment(Result, '}', False);
         Inc(i, 2);
         end
      else if Src[i] = '{' then
         begin
         j := i + 1;

         while (j <= Len) and (Src[j] <> '}') do
            begin
            Inc(j);
            end;

         if j > Len then
            begin
            // Unterminated brace -- emit the remainder literally.
            AppendSegment(Result, Copy(Src, i, Len - i + 1), False);
            i := Len + 1;
            end
         else
            begin
            Token := NormalizeClusterToken(Copy(Src, i + 1, j - i - 1));
            Found := False;
            Value := '';

            if Assigned(Lookup) then
               begin
               Found := Lookup(Token, Value);
               end;

            if Found then
               begin
               AppendSegment(Result, Value, True);
               end
            else
               begin
               // Leave the token verbatim, braces included.
               AppendSegment(Result, Copy(Src, i, j - i + 1), False);
               end;

            i := j + 1;
            end;
         end
      else
         begin
         AppendSegment(Result, Src[i], False);
         Inc(i);
         end;
      end;
end;

function SegmentsToText(const Segments: TClusterSegments): string;
var
   i: integer;
begin
   Result := '';

   for i := 0 to Length(Segments) - 1 do
      begin
      Result := Result + Segments[i].Text;
      end;
end;

end.

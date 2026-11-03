unit uCaptionText;
{$I ..\..\tr4w.inc}

(* THE TEXT A CAPTION PAINTS, with its '&' markup taken out.

   A menu row's caption is markup: a lone '&' marks the underlined letter and
   '&&' is one literal '&'. Some translations carry those markers, so a caption
   put somewhere '&' is NOT markup -- a window title built from a menu row, or a
   measurement of what a button will paint -- goes through DisplayedText first.

   DisplayedText IS Menus.StripHotkey, the LCL's own reading of that markup,
   with one step before it: a CJK caption carries its marker as a suffix group
   -- '<save>(&S)' -- and StripHotkey alone would leave '<save>(S)'. The
   Japanese and Korean catalogues carry such captions, so the group is
   removed whole.

   The parameter is TCaption, the LCL's 8-bit string, so stripping converts
   nothing; the suffix step works on this tree's UTF-16 string, to see the
   fullwidth parentheses as single characters, and converts there and back
   explicitly.

   (Keyboard mnemonics -- assigning '&' letters to captions -- were tried and
   dropped by NY4I on 2026-11-03. TR4W's keyboard commands are ShortCut
   keystrokes, uAccelerators.) *)

interface

uses
   Controls;   (* TCaption *)

(* The text aCaption puts on screen: every '(&X)' suffix group removed with the
   spaces before it, then every lone '&' removed and '&&' read as one '&'. *)
function DisplayedText(const aCaption: TCaption): TCaption;

implementation

uses
   Menus;   (* StripHotkey *)

const
   AMP             = '&';
   FULLWIDTH_OPEN  = #$FF08;
   FULLWIDTH_CLOSE = #$FF09;

function IsOpenParen(c: WideChar): boolean;
begin
   Result := (c = '(') or (c = FULLWIDTH_OPEN);
end;

function IsCloseParen(c: WideChar): boolean;
begin
   Result := (c = ')') or (c = FULLWIDTH_CLOSE);
end;

(* Every '(&X)' group removed whole, with the spaces before it. The '&' must be
   a lone one: '(&&X)' is literal text. *)
function RemoveSuffixGroups(const aCaption: string): string;
var
   i, start: integer;
begin
   Result := aCaption;
   i := 1;
   while i + 3 <= Length(Result) do
      begin
      if IsOpenParen(Result[i])        and
         (Result[i + 1] = AMP)         and
         (Result[i + 2] <> AMP)        and
         IsCloseParen(Result[i + 3]) then
         begin
         start := i;
         while (start > 1) and (Result[start - 1] = ' ') do
            begin
            start := start - 1;
            end;
         Delete(Result, start, (i + 4) - start);
         i := start;
         end
      else
         begin
         i := i + 1;
         end;
      end;
end;

function DisplayedText(const aCaption: TCaption): TCaption;
begin
   Result := StripHotkey(TCaption(RemoveSuffixGroups(string(aCaption))));
end;

end.

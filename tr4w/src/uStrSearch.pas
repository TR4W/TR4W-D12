unit uStrSearch;
{$I tr4w.inc}

(* uStrSearch -- strU, the in-place ASCII upcase of a ShortString.

  Extracted from TF.pas for the Issue #997 inline-asm removal, this unit held
  three x86 routines. Two went on 2026-09-15 with no production caller:
  StrComp_JOH_IA32_6, a strcmp this header already described as uncalled, and
  StrPosPartial, a '?'-wildcard search -- along with PAnsiLen, which only
  StrPosPartial used. Their golden-master tests went with them.

  strU(var Str)
    Upcases the ASCII letters 'a'..'z' of a ShortString IN PLACE; all other
    bytes (digits, punctuation, and >127 extended/code-page characters) are
    left untouched. The original TF.pas routine was declared with a by-value
    parameter but, as a bare 'assembler' proc, received a pointer to the
    caller's string and wrote through it -- so it modified the original. The
    whole case-insensitive config loader depends on this (see the LogCfg
    "Case-Sensitivity Problem" note and the ctPassword re-read STOPGAP). The
    parameter is therefore declared 'var' here to make that real contract
    explicit. *)

interface

procedure strU(var Str: OpenString);

implementation

// NO uses clause, deliberately. This unit exists to be dependency-light enough
// to link into the test harness, and it now has no dependencies at all.
//
// PAnsiLen, StrComp_JOH_IA32_6 and StrPosPartial were here. None had a
// production caller, and they went on 2026-09-15 with their tests.

procedure strU(var Str: OpenString);
var
  i: integer;
begin
  // Upcase only ASCII 'a'..'z' in place (subtract $20); leave every other
  // byte -- digits, punctuation and >127 extended/code-page chars -- alone,
  // exactly as the original asm (CMP 'a'/'z'; JB/JA skip). Equivalence frozen
  // by uTestStrSearch.
  for i := 1 to Length(Str) do
     begin
     if Str[i] in ['a'..'z'] then
        begin
        Str[i] := AnsiChar(Ord(Str[i]) - $20);
        end;
     end;
end;

end.

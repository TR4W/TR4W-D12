unit uStrSearch;

{
  String helpers (PChar substring search + ShortString upcase) extracted from
  TF.pas for the Issue #997 inline-asm removal effort.

  These three routines were originally hand-written x86 inline assembler
  (JOH-style IA32). They are extracted here into a dependency-light unit so
  that:

    1. Their exact behavior can be frozen by golden-master unit tests
       (uTestStrSearch) -- TF.pas itself cannot be linked into the test
       harness because it pulls in MainUnit and the whole UI graph.
    2. The asm bodies were then replaced with the Delphi RTL / pure Pascal
       (see implementation) and proven equivalent against the frozen baseline.

  TF.pas keeps the public names (StrPos, StrPosPartial, StrComp_JOH_IA32_6)
  and forwards here, so existing callers are unaffected.

  SEMANTICS (must be preserved exactly):

    StrPos(Str1, Str2)
      Returns a pointer to the first occurrence of Str2 within Str1, or nil
      if not found / either argument nil / Str2 longer than Str1. Identical
      contract to SysUtils.StrPos.

    StrComp_JOH_IA32_6(Str1, Str2)
      Standard C strcmp: <0, 0, >0. Identical contract to SysUtils.StrComp.
      (Currently uncalled in the codebase, retained for API stability.)

    StrPosPartial(Str1, Str2)
      Like StrPos, but a '?' in Str2 matches any single character -- EXCEPT
      for the FIRST character of Str2, which is always matched literally
      (the original asm seeds the scan with an exact match on Str2[0], so a
      leading '?' looks for a literal '?'). Returns a pointer into Str1 to
      the start of the match, or nil.

    StrU(var Str)
      Upcases the ASCII letters 'a'..'z' of a ShortString IN PLACE; all other
      bytes (digits, punctuation, and >127 extended/code-page characters) are
      left untouched. The original TF.pas routine was declared with a by-value
      parameter but, as a bare 'assembler' proc, received a pointer to the
      caller's string and wrote through it -- so it modified the original. The
      whole case-insensitive config loader depends on this (see the LogCfg
      "Case-Sensitivity Problem" note and the ctPassword re-read STOPGAP). The
      parameter is therefore declared 'var' here to make that real contract
      explicit; all call sites (TF only) already pass a local variable.
}

interface

function StrPosPartial(const Str1, Str2: PAnsiChar): PAnsiChar;
function StrComp_JOH_IA32_6(const Str1, Str2: PAnsiChar): integer;
procedure StrU(var Str: ShortString);

implementation

// NO uses clause, deliberately. This unit exists to be dependency-light enough
// to link into the test harness, and it now has no dependencies at all.
//
// It previously used System.AnsiStrings for StrLen and StrComp. That unit has
// NO FreePascal equivalent -- FPC ships the classic `strings` unit instead, so
// System.AnsiStrings is not a "drop the prefix" case the way System.SysUtils
// is. Both routines it borrowed are a handful of lines, so the portable answer
// is to own them rather than to shim around the difference with {$IFDEF FPC}.

// Length of a NUL-terminated byte string, replacing AnsiStrings.StrLen.
function PAnsiLen(const p: PAnsiChar): integer;
var
  q: PAnsiChar;
begin
  q := p;
  while q^ <> #0 do
    begin
    Inc(q);
    end;
  Result := q - p;
end;

// Issue #997: x86 inline-asm bodies replaced by pure Pascal.
// Equivalence to the original asm is frozen by uTestStrSearch (31 golden cases).

function StrComp_JOH_IA32_6(const Str1, Str2: PAnsiChar): integer;
var
  p1: PAnsiChar;
  p2: PAnsiChar;
begin
  // The original asm normalized its result to exactly -1 / 0 / +1
  // (sbb eax,eax; or al,1), unlike the RTL's StrComp, which returns the raw
  // byte difference of the first mismatch (e.g. '' vs 'A' -> -65). The -1/0/+1
  // contract is what uTestStrSearch pins, so it is produced directly here.
  //
  // AnsiChar compares by ordinal 0..255, i.e. UNSIGNED, so a byte >= $80 sorts
  // after every ASCII character -- matching both the assembly and the RTL.
  p1 := Str1;
  p2 := Str2;
  while (p1^ <> #0) and (p1^ = p2^) do
    begin
    Inc(p1);
    Inc(p2);
    end;

  if p1^ < p2^ then
    begin
    Result := -1;
    end
  else if p1^ > p2^ then
    begin
    Result := 1;
    end
  else
    begin
    Result := 0;
    end;
end;

function StrPosPartial(const Str1, Str2: PAnsiChar): PAnsiChar;
var
  Len1, Len2: integer;
  i, j: integer;
  Matched: boolean;
begin
  // Like StrPos, but '?' in Str2 matches any single character -- EXCEPT the
  // FIRST pattern character, which is always matched literally (the original
  // asm seeded its scan with an exact match on Str2[0], so a leading '?'
  // looks for a literal '?'). See uTestStrSearch for the frozen cases.
  Result := nil;
  if (Str1 = nil) or (Str2 = nil) then
    Exit;

  Len2 := PAnsiLen(Str2);
  if Len2 = 0 then          // empty pattern -> nil (matches the asm)
    Exit;

  Len1 := PAnsiLen(Str1);
  if Len1 < Len2 then       // pattern longer than text -> nil
    Exit;

  for i := 0 to Len1 - Len2 do
    begin
    // First character is literal (no wildcard), exactly as the asm scan.
    if Str1[i] <> Str2[0] then
      Continue;

    Matched := True;
    for j := 1 to Len2 - 1 do
      begin
      if (Str1[i + j] <> Str2[j]) and (Str2[j] <> '?') then
        begin
        Matched := False;
        Break;
        end;
      end;

    if Matched then
      begin
      Result := Str1 + i;
      Exit;
      end;
    end;
end;

// StrPos removed (D12): it was a pure System.AnsiStrings.StrPos forwarder;
// callers use the RTL directly now. StrPosPartial (?-wildcard) stays -- it is
// genuine custom logic, not an RTL duplicate.

procedure StrU(var Str: ShortString);
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
      Str[i] := AnsiChar(Ord(Str[i]) - $20);
    end;
end;

end.

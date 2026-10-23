unit uDomFileKeys;

(* THE KEYS A DOMESTIC (.dom) FILE DECLARES -- and whether one of them is a
  given QTH.

  WHY IT EXISTS: IN-STATE DETECTION FOR A QSO PARTY. FCONTEST asks whether the
  operator's MY STATE is one of the keys of the party's county file -- an
  in-state station's "state" is its county -- and picks the in-state or the
  out-of-state domestic file, exchange and multipliers from the answer.

  THAT QUESTION HAD NEVER BEEN ANSWERED YES IN THIS TREE (inventory defect #1,
  docs/CONTEST_OWNERSHIP_DESIGN.md section 8.2a). The path was built as
  'DOM' + name + '.DOM', with no separator -- D7 wrote '%sDOM\%s.DOM' -- so the
  file was never found and every station was out of state. The path now comes
  from uAppPaths.ShippedDomFilePath; this unit is the reading half.

  A LEAF, SO THE RULE CAN BE PINNED. It replaces FCONTEST's EnumDOM2, which was
  a PShortString callback writing a unit-level InState flag -- a shape no test
  could reach. The rule is EnumDOM2's, line for line:
    a line declares a key only if it holds '=';
    the key is the text before the first '=', cut at the first '>';
    surrounding white space is dropped.
  An INCLUDE FILE line has no '=' and so declares nothing; includes are not
  followed, exactly as before.

  ONE DELIBERATE DIFFERENCE: THE COMPARISON IGNORES CASE. EnumDOM2 upper-cased
  the LINE and compared it with MY STATE as typed, so a lower-case MY STATE
  could never be in state. A county code is not case-significant anywhere else
  in the program. *)

{$I tr4w.inc}

interface

uses
   Classes;

const
   (* A DOMESTIC FILE'S EXTENSION. FCONTEST appends it to a contest's
     domestic file name, and LOGSTUFF's domestic-QTH refusal to a party's
     in-state file name (moved here from FCONTEST, 2026-10-23, for the
     second user). TYPED, so appending it to an AnsiString is not a
     narrowing conversion: a bare '.dom' is a UnicodeString literal in this
     tree and the ratchet counts every one of those. *)
   DOM_EXTENSION: AnsiString = '.dom';

(* The key aLine declares, upper-cased, or '' when it declares none. *)
function DomFileLineKey(const aLine: string): string;

(* Does any line of aLines declare aKey? Never True for an empty aKey: an
  operator with no MY STATE is in nobody's state. *)
function DomFileDeclaresKey(const aLines: TStrings; const aKey: string): boolean;

(* The same, of the file at aPath. False when there is no such file -- a
  contest whose county file is missing has no in-state stations, which is
  what the caller has always been told in that case. *)
function DomFileOnDiskDeclaresKey(const aPath, aKey: string): boolean;

(* ---------------------------------------------------------------------------
  THE ALIASES A LINE GIVES -- the RIGHT side of 'MULTIPLIER = alias, alias',
  which is what a received QTH is matched against. 2026-10-23.

  WHY IT EXISTS: THE IMPROPER-DOMESTIC-QTH MESSAGE NAMES ITS REASON. An
  out-of-state entrant in a state QSO party has the host's COUNTY file
  loaded, so 'CT' is refused there exactly as a typo is. Whether the text is
  a place the contest knows at all -- a state, so the reason is the
  host-area rule -- is answered by the party's IN-STATE file, which this
  session never loaded. LOGSTUFF asks it here, on the refusal path only.

  NOT LOGDOM'S LOADER, ON PURPOSE. TDomQTHTable.ReadDomQTHFile's line
  callback also adds every multiplier to the live multiplier sheet
  (mo.DomList), so loading a second file into a scratch table would put the
  in-state file's states on an out-of-state entrant's sheet. This reads the
  same lines by the same rule and touches nothing.

  THE RULE IS EnumDOMFILE's, for what it stores:
    an alias is one comma-separated item after the first '=';
    surrounding white space is dropped and it is upper-cased;
    an item beginning '^' is a display name, not an alias;
    only an alias starting 0-9 or A-Z is stored (AddNewPrefixRecord);
    a stored alias is cut to ten characters (Str10), so a text longer than
      ten is never found -- FindAlias compares the whole text. *)
function DomFileLineHasAlias(const aLine, aAlias: string): boolean;

(* The file an 'INCLUDE FILE <name>' line names, or '' for any other line. *)
function DomFileLineInclude(const aLine: string): string;

(* Does the file aFileName in aDomDir, or a file it INCLUDEs, give aAlias as
  an alias? An INCLUDE is looked for in aDomDir: every shipped .dom lives in
  one directory, which is where EnumDOMFILE looks too (ShippedDomFilePath).
  The name is matched in any case (uAppPaths.ExistingDataFile), as the
  loader's is. False for a missing file -- the reason then falls back to
  "not in the list", which is still true. *)
function DomFileInDirHasAlias(const aDomDir, aFileName, aAlias: string): boolean;

implementation

uses
   SysUtils,
   uAppPaths;   (* ExistingDataFile -- an INCLUDE's name in any case *)

const
   DOM_INCLUDE_PREFIX = 'INCLUDE FILE';

   (* INCLUDE depth. The shipped files nest three deep (georgia -> S50 ->
     S48); this only stops a file that includes itself. *)
   DOM_INCLUDE_DEPTH_MAX = 8;

   (* Str10, the width AddNewPrefixRecord stores an alias in. *)
   DOM_ALIAS_WIDTH_MAX = 10;

function DomFileLineKey(const aLine: string): string;
var
   p: integer;
begin
   Result := '';
   p := Pos('=', aLine);
   if p = 0 then
      begin
      Exit;
      end;

   Result := Copy(aLine, 1, p - 1);
   p := Pos('>', Result);
   if p > 0 then
      begin
      Result := Copy(Result, 1, p - 1);
      end;
   Result := UpperCase(Trim(Result));
end;

function DomFileDeclaresKey(const aLines: TStrings; const aKey: string): boolean;
var
   key: string;
   i: integer;
begin
   Result := False;
   key := UpperCase(Trim(aKey));
   if key = '' then
      begin
      Exit;
      end;

   for i := 0 to aLines.Count - 1 do
      begin
      if DomFileLineKey(aLines[i]) = key then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function DomFileOnDiskDeclaresKey(const aPath, aKey: string): boolean;
var
   lines: TStringList;
begin
   Result := False;
   if not FileExists(aPath) then
      begin
      Exit;
      end;

   lines := TStringList.Create;
   try
      (* EXPLICIT AT THE BOUNDARY: TStrings.LoadFromFile takes the RTL's
        AnsiString file name, and a path is the one value here that crosses. *)
      lines.LoadFromFile(AnsiString(aPath));
      Result := DomFileDeclaresKey(lines, aKey);
   finally
      lines.Free;
      end;
end;

function DomFileLineHasAlias(const aLine, aAlias: string): boolean;
var
   wanted: string;
   rest: string;
   item: string;
   p: integer;
begin
   Result := False;
   wanted := UpperCase(Trim(aAlias));
   if (wanted = '') or (Length(wanted) > DOM_ALIAS_WIDTH_MAX) then
      begin
      Exit;
      end;

   p := Pos('=', aLine);
   if p = 0 then
      begin
      Exit;
      end;

   rest := Copy(aLine, p + 1, Length(aLine));
   while rest <> '' do
      begin
      p := Pos(',', rest);
      if p > 0 then
         begin
         item := Copy(rest, 1, p - 1);
         rest := Copy(rest, p + 1, Length(rest));
         end
      else
         begin
         item := rest;
         rest := '';
         end;

      item := UpperCase(Trim(item));
      if (item <> '')                                    and
         (((item[1] >= '0') and (item[1] <= '9')) or
          ((item[1] >= 'A') and (item[1] <= 'Z')))       and
         (Copy(item, 1, DOM_ALIAS_WIDTH_MAX) = wanted) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function DomFileLineInclude(const aLine: string): string;
var
   line: string;
begin
   Result := '';
   line := TrimLeft(aLine);
   if Copy(line, 1, Length(DOM_INCLUDE_PREFIX)) = DOM_INCLUDE_PREFIX then
      begin
      Result := Trim(Copy(line, Length(DOM_INCLUDE_PREFIX) + 1, Length(line)));
      end;
end;

function DomFileInDirHasAliasAtDepth(const aDomDir, aFileName, aAlias: string;
                                     aDepth: integer): boolean;
var
   path: string;
   lines: TStringList;
   included: string;
   i: integer;
begin
   Result := False;
   if aDepth > DOM_INCLUDE_DEPTH_MAX then
      begin
      Exit;
      end;

   path := ExistingDataFile(IncludeTrailingPathDelimiter(aDomDir) + aFileName);
   if not FileExists(path) then
      begin
      Exit;
      end;

   lines := TStringList.Create;
   try
      (* EXPLICIT AT THE BOUNDARY -- see DomFileOnDiskDeclaresKey. *)
      lines.LoadFromFile(AnsiString(path));
      for i := 0 to lines.Count - 1 do
         begin
         included := DomFileLineInclude(lines[i]);
         if included <> '' then
            begin
            if DomFileInDirHasAliasAtDepth(aDomDir, included, aAlias,
                                           aDepth + 1) then
               begin
               Result := True;
               Exit;
               end;
            end
         else if DomFileLineHasAlias(lines[i], aAlias) then
            begin
            Result := True;
            Exit;
            end;
         end;
   finally
      lines.Free;
      end;
end;

function DomFileInDirHasAlias(const aDomDir, aFileName, aAlias: string): boolean;
begin
   Result := DomFileInDirHasAliasAtDepth(aDomDir, aFileName, aAlias, 0);
end;

end.

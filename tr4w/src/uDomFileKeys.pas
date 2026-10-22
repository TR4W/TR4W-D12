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

(* The key aLine declares, upper-cased, or '' when it declares none. *)
function DomFileLineKey(const aLine: string): string;

(* Does any line of aLines declare aKey? Never True for an empty aKey: an
  operator with no MY STATE is in nobody's state. *)
function DomFileDeclaresKey(const aLines: TStrings; const aKey: string): boolean;

(* The same, of the file at aPath. False when there is no such file -- a
  contest whose county file is missing has no in-state stations, which is
  what the caller has always been told in that case. *)
function DomFileOnDiskDeclaresKey(const aPath, aKey: string): boolean;

implementation

uses
   SysUtils;

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

end.

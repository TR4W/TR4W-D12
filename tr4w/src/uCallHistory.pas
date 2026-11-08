(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* A CALL HISTORY FILE -- the community-maintained "call history" files N1MM
  reads (https://n1mmwp.hamdocs.com/setup/call-history/), which carry what each
  station sent in past runnings of a contest. NY4I, 2026-11-07, for the ARRL
  Sweepstakes: prefill the check and the section.

  THIS UNIT READS THE FILE AND NOTHING ELSE. It is a leaf (no engine, no
  globals, no window), so the unit tests feed it inline text. What a contest
  takes from a row is the CONTEST'S statement (TContestBase.CallHistoryFields);
  where the text goes is the caller's (LOGDUPE.LoadCallHistoryFile, into the
  initial-exchange store CallsignsList, as a call-history entry).

  THE FORMAT, as N1MM states it and as the files in circulation write it:
    * comma OR semicolon delimited -- both are treated as a delimiter, since no
      field a call history carries holds either;
    * a line whose first non-blank character is '#' is a comment; a blank line
      is nothing;
    * '!!Order!!,Call,Sect,State,CK,Exch1,' names the columns of the lines that
      follow, case-blind; a blank name (the trailing comma above) or a name this
      unit does not know skips that column; it may appear again mid-file;
    * without it the columns are N1MM's default order (DEFAULT_ORDER below);
    * any other '!!Name!!' line is a directive N1MM implements
      (MapStateToSect, FourCharGridSq, ValidateArrlSection ...). NONE is
      implemented here: it is skipped and its name remembered, so the caller
      can say so once;
    * a short row and an empty field are normal; a value longer than the
      field's maximum is cut to it; a CK that is not all digits is discarded,
      and a one-digit CK is written with its leading zero (a check is the last
      two digits of a year: the files write 2008 as '8').

  NOT A CSV PARSER: no quoting. The files in circulation carry none, and N1MM's
  description has none. *)
unit uCallHistory;

{$I tr4w.inc}

interface

uses
   Classes;

type
   (* N1MM'S FIELDS, IN N1MM'S DEFAULT COLUMN ORDER -- the order is load-bearing:
      a file with no !!Order!! line is read in this order. *)
   TCallHistoryField = (chfCall, chfName, chfLoc1, chfLoc2, chfSect, chfState, chfCK,
                        chfBirthDate, chfExch1, chfMisc, chfPower, chfCqZone, chfITUZone,
                        chfUserText, chfLastUpdateNote);

   (* What a contest prefills from a row, in the order it is written. *)
   TCallHistoryFields = array of TCallHistoryField;

   (* The words of one line. *)
   TCallHistoryWords = array of string;

   (* One row's values, '' for a field the row does not carry. *)
   TCallHistoryValues = array[TCallHistoryField] of string;

   (* WHAT THE STORE DID WITH A ROW'S EXCHANGE -- the caller's answer, counted. *)
   TCallHistoryAddResult = (charAdded, charAlreadyKnown, charStoreFull);

   (* THE STORE: given a call and the text the contest builds from its row. *)
   TCallHistoryAddFunc = function(const aCall: string; const aExchange: string): TCallHistoryAddResult;

   (* THE READER: the column order in force, the directives met, and what
      happened to the rows. One reader per file read. *)
   TCallHistoryReader = class
   private
      (* Per column: Ord of its field, or -1 to skip it. *)
      FColumns: array of integer;
      FUnknownDirectives: TCallHistoryWords;
      FDataRows: integer;
      FAdded: integer;
      FAlreadyKnown: integer;
      FStoreFull: integer;
      FIncomplete: integer;
      procedure SetDefaultOrder;
      procedure ReadOrder(const aWords: TCallHistoryWords);
      procedure NoteDirective(const aName: string);
   public
      constructor Create;
      destructor Destroy; override;

      (* ONE LINE OF THE FILE. True when it is a data row with a call, aValues
         then holding its fields; False for a comment, a blank line, a
         directive (an !!Order!! line changes the column order for the lines
         after it) or a row with no call. *)
      function ReadLine(const aLine: string; out aValues: TCallHistoryValues): boolean;

      (* EVERY LINE, each data row's exchange built from aFields
         (CallHistoryExchangeText) and handed to aAdd. A row missing any of
         aFields is counted Incomplete and handed to no one. *)
      procedure ReadAll(aLines: TStrings; const aFields: array of TCallHistoryField;
                        aAdd: TCallHistoryAddFunc);

      (* Data rows met (a call present), and what became of them. *)
      property DataRows: integer read FDataRows;
      property Added: integer read FAdded;
      property AlreadyKnown: integer read FAlreadyKnown;
      property StoreFull: integer read FStoreFull;
      property Incomplete: integer read FIncomplete;
      (* Each directive name other than Order, once, as the file spells it,
         joined with ', '; '' for none. *)
      function UnknownDirectives: string;
   end;

(* N1MM's name of a field ('Sect', 'CK' ...), case-blind. *)
function CallHistoryFieldOfName(const aName: string; out aField: TCallHistoryField): boolean;

(* The name N1MM gives a field -- for a log line or a message. *)
function CallHistoryFieldName(aField: TCallHistoryField): string;

(* THE EXCHANGE TEXT A CONTEST PREFILLS: the values of aFields in aFields'
   order, one blank between them. False (and '') when aFields is empty or a
   named field is empty in this row -- a partial row is not prefilled. *)
function CallHistoryExchangeText(const aValues: TCallHistoryValues;
                                 const aFields: array of TCallHistoryField;
                                 out aText: string): boolean;

(* WHERE A CALL HISTORY FILE IS: a name with a directory is used as it is;
   a bare name is looked for in the CallHistoryFiles folder -- the writable
   data directory's copy first, then the one beside the program
   (uAppPaths.PreferredDataFilePath), matched case-tolerantly. '' for ''. *)
function CallHistoryFilePath(const aName: string): string;

(* THE LINES OF A FILE, a UTF-8 byte-order mark removed. False, aLines
   empty, when the file cannot be read; never raises. *)
function ReadCallHistoryLines(const aPath: string; aLines: TStringList): boolean;

const
   (* The folder a bare CALL HISTORY FILENAME is looked for in. *)
   CALL_HISTORY_FOLDER = 'CallHistoryFiles';

implementation

uses
   SysUtils,
   uAppPaths;

const
   FIELD_NAMES: array[TCallHistoryField] of string = (
      'Call', 'Name', 'Loc1', 'Loc2', 'Sect', 'State', 'CK',
      'BirthDate', 'Exch1', 'Misc', 'Power', 'CqZone', 'ITUZone',
      'UserText', 'LastUpdateNote');

   (* N1MM's maximum lengths; 0 is "N1MM states none". *)
   FIELD_MAX: array[TCallHistoryField] of integer = (
      15, 20, 6, 6, 8, 8, 0,
      0, 12, 15, 8, 0, 0,
      60, 0);

function CallHistoryFieldOfName(const aName: string; out aField: TCallHistoryField): boolean;
var
   f: TCallHistoryField;
   name: string;
begin
   Result := False;
   aField := chfCall;
   name := Trim(aName);
   for f := Low(TCallHistoryField) to High(TCallHistoryField) do
      begin
      if UnicodeSameText(name, FIELD_NAMES[f]) then
         begin
         aField := f;
         Result := True;
         Exit;
         end;
      end;
end;

function CallHistoryFieldName(aField: TCallHistoryField): string;
begin
   Result := FIELD_NAMES[aField];
end;

(* The words of a line, split at every ',' and ';', each trimmed. A trailing
   delimiter gives a trailing empty word, which is harmless: it skips. *)
function SplitWords(const aLine: string): TCallHistoryWords;
var
   i: integer;
   start: integer;
   n: integer;
begin
   Result := nil;
   n := 1;
   for i := 1 to Length(aLine) do
      begin
      if (aLine[i] = ',') or (aLine[i] = ';') then
         begin
         inc(n);
         end;
      end;
   SetLength(Result, n);
   n := 0;
   start := 1;
   for i := 1 to Length(aLine) do
      begin
      if (aLine[i] = ',') or (aLine[i] = ';') then
         begin
         Result[n] := Trim(Copy(aLine, start, i - start));
         inc(n);
         start := i + 1;
         end;
      end;
   Result[n] := Trim(Copy(aLine, start, Length(aLine) - start + 1));
end;

function AllDigits(const s: string): boolean;
var
   i: integer;
begin
   Result := s <> '';
   for i := 1 to Length(s) do
      begin
      if (s[i] < '0') or (s[i] > '9') then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

(* A value as the field holds it: cut to the field's maximum; a CK that is
   not all digits is no CK ('-1' in the files is "unknown"), and a one-digit
   CK gets its leading zero. *)
function FieldValue(aField: TCallHistoryField; const aText: string): string;
begin
   Result := aText;
   if aField = chfCK then
      begin
      if not AllDigits(Result) then
         begin
         Result := '';
         end
      else if Length(Result) = 1 then
         begin
         Result := '0' + Result;
         end;
      end;
   if aField = chfCall then
      begin
      Result := UpperCase(Result);
      end;
   if (FIELD_MAX[aField] > 0) and (Length(Result) > FIELD_MAX[aField]) then
      begin
      Result := Copy(Result, 1, FIELD_MAX[aField]);
      end;
end;

constructor TCallHistoryReader.Create;
begin
   inherited Create;
   SetDefaultOrder;
end;

destructor TCallHistoryReader.Destroy;
begin
   inherited Destroy;
end;

procedure TCallHistoryReader.NoteDirective(const aName: string);
var
   i: integer;
begin
   for i := 0 to High(FUnknownDirectives) do
      begin
      if UnicodeSameText(FUnknownDirectives[i], aName) then
         begin
         Exit;
         end;
      end;
   SetLength(FUnknownDirectives, Length(FUnknownDirectives) + 1);
   FUnknownDirectives[High(FUnknownDirectives)] := aName;
end;

function TCallHistoryReader.UnknownDirectives: string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(FUnknownDirectives) do
      begin
      if Result <> '' then
         begin
         Result := Result + ', ';
         end;
      Result := Result + FUnknownDirectives[i];
      end;
end;

procedure TCallHistoryReader.SetDefaultOrder;
var
   f: TCallHistoryField;
begin
   SetLength(FColumns, Ord(High(TCallHistoryField)) + 1);
   for f := Low(TCallHistoryField) to High(TCallHistoryField) do
      begin
      FColumns[Ord(f)] := Ord(f);
      end;
end;

(* aWords[0] is the directive itself; the column names follow it. *)
procedure TCallHistoryReader.ReadOrder(const aWords: TCallHistoryWords);
var
   i: integer;
   f: TCallHistoryField;
begin
   SetLength(FColumns, Length(aWords) - 1);
   for i := 1 to High(aWords) do
      begin
      if CallHistoryFieldOfName(aWords[i], f) then
         begin
         FColumns[i - 1] := Ord(f);
         end
      else
         begin
         FColumns[i - 1] := -1;
         end;
      end;
end;

function TCallHistoryReader.ReadLine(const aLine: string; out aValues: TCallHistoryValues): boolean;
var
   line: string;
   words: TCallHistoryWords;
   directive: string;
   closing: integer;
   i: integer;
   f: TCallHistoryField;
begin
   Result := False;
   for f := Low(TCallHistoryField) to High(TCallHistoryField) do
      begin
      aValues[f] := '';
      end;

   line := Trim(aLine);
   if (line = '') or (line[1] = '#') then
      begin
      Exit;
      end;

   words := SplitWords(line);

   (* A DIRECTIVE: '!!Name!!' in the first word. *)
   if Copy(line, 1, 2) = '!!' then
      begin
      directive := Copy(words[0], 3, MaxInt);
      closing := Pos('!!', directive);
      if closing > 0 then
         begin
         directive := Copy(directive, 1, closing - 1);
         end;
      if UnicodeSameText(directive, 'Order') then
         begin
         ReadOrder(words);
         end
      else
         begin
         NoteDirective(directive);
         end;
      Exit;
      end;

   for i := 0 to High(words) do
      begin
      if (i <= High(FColumns)) and (FColumns[i] >= 0) then
         begin
         f := TCallHistoryField(FColumns[i]);
         aValues[f] := FieldValue(f, words[i]);
         end;
      end;

   Result := aValues[chfCall] <> '';
end;

procedure TCallHistoryReader.ReadAll(aLines: TStrings; const aFields: array of TCallHistoryField;
                                     aAdd: TCallHistoryAddFunc);
var
   i: integer;
   values: TCallHistoryValues;
   text: string;
begin
   for i := 0 to aLines.Count - 1 do
      begin
      if not ReadLine(string(aLines[i]), values) then
         begin
         Continue;
         end;
      inc(FDataRows);
      if not CallHistoryExchangeText(values, aFields, text) then
         begin
         inc(FIncomplete);
         Continue;
         end;
      case aAdd(values[chfCall], text) of
         charAdded:
            begin
            inc(FAdded);
            end;
         charAlreadyKnown:
            begin
            inc(FAlreadyKnown);
            end;
         charStoreFull:
            begin
            inc(FStoreFull);
            end;
      end;
      end;
end;

function CallHistoryExchangeText(const aValues: TCallHistoryValues;
                                 const aFields: array of TCallHistoryField;
                                 out aText: string): boolean;
var
   i: integer;
begin
   aText := '';
   Result := Length(aFields) > 0;
   for i := Low(aFields) to High(aFields) do
      begin
      if aValues[aFields[i]] = '' then
         begin
         aText := '';
         Result := False;
         Exit;
         end;
      if aText <> '' then
         begin
         aText := aText + ' ';
         end;
      aText := aText + aValues[aFields[i]];
      end;
end;

function CallHistoryFilePath(const aName: string): string;
begin
   if Trim(aName) = '' then
      begin
      Result := '';
      end
   else if ExtractFilePath(aName) <> '' then
      begin
      Result := aName;
      end
   else
      begin
      Result := PreferredDataFilePath(CALL_HISTORY_FOLDER + PathDelim + Trim(aName));
      end;
end;

function ReadCallHistoryLines(const aPath: string; aLines: TStringList): boolean;
var
   first: AnsiString;
begin
   aLines.Clear;
   Result := False;
   if (aPath = '') or (not FileExists(aPath)) then
      begin
      Exit;
      end;
   try
      (* AnsiString: the RTL's file name here is an AnsiString, as TF.EnumerateLinesInFile's. *)
      aLines.LoadFromFile(AnsiString(aPath));
   except
      aLines.Clear;
      Exit;
   end;
   (* THE MARK IS COMPARED AS BYTES: the lines are AnsiStrings holding the
      file's bytes, and a comparison with a string constant would convert
      through the system code page first -- which differs between Windows
      and a UTF-8 Linux. *)
   if aLines.Count > 0 then
      begin
      first := aLines[0];
      if (Length(first) >= 3)    and
         (Ord(first[1]) = $EF)   and
         (Ord(first[2]) = $BB)   and
         (Ord(first[3]) = $BF)   then
         begin
         aLines[0] := Copy(first, 4, MaxInt);
         end;
      end;
   Result := True;
end;

end.

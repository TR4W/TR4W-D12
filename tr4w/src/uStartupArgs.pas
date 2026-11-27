unit uStartupArgs;

(* WHAT THE COMMAND LINE ASKS FOR, as pure functions over an argument list, so
  the unit tests can pin them.

  WHY --unattended EXISTS (NY4I, 2026-11-26). A script ran /IMPORTLOG from Git
  Bash, which rewrote the switch into "C:/Program Files/Git/IMPORTLOG".  TR4W
  did not recognise it, started as for an operator, asked whether to download a
  country file, and waited from 06:34 until NY4I came in.

  --unattended says "nobody is here": the command line must name a job that ends
  the program by itself, or TR4W exits at once with EXITCODE_UNATTENDED.  Being
  spelled with two dashes it is not rewritten as a path by Git Bash, so it still
  arrives when the argument beside it has been mangled.

  IT IS NOT tSilentExport.  That flag means "do not ask, carry on with the
  default"; this one means "if the job cannot finish by itself, stop". *)

{$IFDEF FPC}{$MODE Delphi}{$MODESWITCH UnicodeStrings}{$ENDIF}

interface

type
   TStartupArgs = array of string;

const
   SWITCH_UNATTENDED = '--unattended';

(* ParamStr(1)..ParamStr(ParamCount). *)
function CommandLineStartupArgs: TStartupArgs;

function ArgumentsRequestUnattended(const aArgs: array of string): boolean;

(* The arguments without --unattended, --settings and --lang (and the values the
  last two take).  The headless jobs are read BY POSITION -- the contest file,
  then /EXPORT -- so a switch that may be written anywhere must not move them. *)
function PositionalArguments(const aArgs: array of string): TStartupArgs;

(* The 1-based positional argument, '' past the end: ParamStr over
  PositionalArguments. *)
function PositionalArgumentOf(const aArgs: array of string;
                              aIndex: integer): string;
function PositionalArgument(aIndex: integer): string;

(* The file named after /IMPORT, wherever /IMPORT stands, or ''. *)
function ImportFileOf(const aArgs: array of string): string;

(* A headless switch has no operator, so nothing may open a dialog.  Asked of
  every argument: an earlier version asked ParamStr(2) alone, and `tr4w.exe
  /EXPORT` started an interactive session. *)
function IsHeadlessSwitch(const aArg: string): boolean;
function ArgumentsHaveHeadlessSwitch(const aArgs: array of string): boolean;

(* True when this command line names a job TR4W will do and then exit -- each
  one tested at the position uProgramMain reads it from. *)
function ArgumentsNameAHeadlessJob(const aArgs: array of string): boolean;

implementation

uses
   SysUtils;

function CommandLineStartupArgs: TStartupArgs;
var
   i: integer;
begin
   SetLength(Result, ParamCount);
   for i := 1 to ParamCount do
      begin
      Result[i - 1] := ParamStr(i);
      end;
end;

function ArgumentsRequestUnattended(const aArgs: array of string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(aArgs) to High(aArgs) do
      begin
      if UnicodeSameText(aArgs[i], SWITCH_UNATTENDED) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function PositionalArguments(const aArgs: array of string): TStartupArgs;
var
   i, count: integer;
   arg: string;
begin
   SetLength(Result, Length(aArgs));
   count := 0;
   i := Low(aArgs);
   while i <= High(aArgs) do
      begin
      arg := aArgs[i];
      Inc(i);

      if UnicodeSameText(arg, '--settings') or UnicodeSameText(arg, '--lang')
         or UnicodeSameText(arg, '-l') then
         begin
         Inc(i);        // the value after it
         Continue;
         end;

      if UnicodeSameText(arg, SWITCH_UNATTENDED)
         or (Pos('--settings=', LowerCase(arg)) = 1)
         or (Pos('--lang=', LowerCase(arg)) = 1) then
         begin
         Continue;
         end;

      Result[count] := arg;
      Inc(count);
      end;
   SetLength(Result, count);
end;

function PositionalArgumentOf(const aArgs: array of string;
                              aIndex: integer): string;
var
   positional: TStartupArgs;
begin
   Result := '';
   positional := PositionalArguments(aArgs);
   if (aIndex >= 1) and (aIndex <= Length(positional)) then
      begin
      Result := positional[aIndex - 1];
      end;
end;

function PositionalArgument(aIndex: integer): string;
begin
   Result := PositionalArgumentOf(CommandLineStartupArgs, aIndex);
end;

function ImportFileOf(const aArgs: array of string): string;
var
   positional: TStartupArgs;
   i: integer;
begin
   Result := '';
   positional := PositionalArguments(aArgs);
   for i := 0 to Length(positional) - 2 do
      begin
      if UnicodeSameText(positional[i], '/IMPORT') then
         begin
         Result := positional[i + 1];
         Exit;
         end;
      end;
end;

function IsHeadlessSwitch(const aArg: string): boolean;
begin
   (* /FIELDCHECK is deliberately absent: it halts before any of this and never
     reaches a contest file. *)
   Result := UnicodeSameText(aArg, '/EXPORT') or
             UnicodeSameText(aArg, '/RESCORE') or
             UnicodeSameText(aArg, '/IMPORT') or
             UnicodeSameText(aArg, '/IMPORTLOG') or
             UnicodeSameText(aArg, '/MATRIX') or
             UnicodeSameText(aArg, '/MATRIXLIST') or
             UnicodeSameText(aArg, '/ENTERQSO');
end;

function ArgumentsHaveHeadlessSwitch(const aArgs: array of string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(aArgs) to High(aArgs) do
      begin
      if IsHeadlessSwitch(aArgs[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function ArgumentsNameAHeadlessJob(const aArgs: array of string): boolean;
var
   first, second: string;
begin
   first  := PositionalArgumentOf(aArgs, 1);
   second := PositionalArgumentOf(aArgs, 2);
   Result := UnicodeSameText(first, '/IMPORTLOG') or
             UnicodeSameText(first, '/MATRIXLIST') or
             UnicodeSameText(first, '/FIELDCHECK') or
             UnicodeSameText(second, '/EXPORT') or
             UnicodeSameText(second, '/RESCORE') or
             UnicodeSameText(second, '/MATRIX') or
             UnicodeSameText(second, '/ENTERQSO') or
             (ImportFileOf(aArgs) <> '');
end;

end.

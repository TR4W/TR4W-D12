unit uOpenLogRelaunch;

(* FILE > OPEN LOG... -- THE DECISIONS, WITHOUT THE LCL (issue 218, stage S0).

  WHAT THE MENU ITEM DOES. The operator picks another contest log; TR4W closes
  through the ordinary exit path (ExitProgram -> tr4w_ShutDown, so the restart
  file, the score to UDP, the backup stop, the network departure and
  LogStoreClose all run exactly as they do for File > Exit) and then starts
  itself again with the chosen file as its argument. Nothing is reset in place:
  the 2026-11-05 survey on issue 218 lists the state that leaks from one
  contest into the next when the open path is simply run twice, and S0 exists
  so the feature is usable before that is fixed (S1-S6).

  THIS UNIT HOLDS EVERY PART OF THAT WHICH CAN BE WRONG WITHOUT A SCREEN, so the
  unit tests can pin it: what refuses the switch, whether the chosen file is the
  one already open, the child's command line, and the switch the child reads.
  MainUnit owns the picker and the menu arm; uProgramMain owns the wait;
  tr4w_ShutDown starts the child.

  THE HAND-OFF. The program is single-instance on Windows (a named mutex, see
  uProgramMain.SingleInstanceMutexName), and the parent still holds that mutex
  when it starts the child -- it cannot release it any earlier without leaving
  a window in which a second copy could start on the same log. So the child is
  given WAIT_FOR_INSTANCE_SWITCH, and while it is present the child retries the
  mutex for up to RELAUNCH_WAIT_MS before treating the instance as a duplicate.
  The parent's process exit is what releases the mutex, so the child cannot
  take it while anything of the parent is still running.

  THE VALUE IS THE PARENT'S PROCESS ID, carried for the log line only. The
  mutex is the thing that is actually waited on; a pid can be reused, a mutex
  name cannot be held by a process that has gone.

  `--switch=value`, ONE ARGUMENT, DELIBERATELY. uProgramMain.FirstNonSwitchArgument
  takes the first argument that does not start with - or / as the contest file,
  so a switch with a separate value would make the pid the contest.

  NO LCL AND NO PLATFORM UNIT. string here is UnicodeString (tr4w.inc), and the
  argument list is an array of it rather than a TStrings, whose AnsiString
  items would narrow every add. *)

{$I tr4w.inc}

interface

type
   (* WHY THE SWITCH IS REFUSED. orNone means it may go ahead. *)
   TOpenLogRefusal = (
      olrNone,          (* nothing on the air -- go ahead *)
      olrTransmitting,  (* a radio is keyed (PTT on either radio) *)
      olrSendingCW      (* a CW message is still being sent *)
   );

   TRelaunchArgs = array of string;

const
   (* The child's "wait for the instance that started me" switch. The value is
      the parent's process id. *)
   WAIT_FOR_INSTANCE_SWITCH = '--wait-for-instance=';

   (* How long the child keeps trying the single-instance lock, and how often.
      Ten seconds covers a shutdown that waits out a network radio's
      disconnect and the QSO dispatcher's one-second drain with room to
      spare; a parent that takes longer than that is stuck, and the child
      then says "already running" exactly as a second copy would. *)
   RELAUNCH_WAIT_MS  = 10000;
   RELAUNCH_RETRY_MS = 200;

(* WHAT REFUSES THE SWITCH. Exiting stops the keyer and unkeys the radios, so a
  switch mid-transmission would cut an over off the air; the operator is told
  why instead. Transmitting is asked before CW because a keyed radio is the
  wider statement -- CW keyed by CAT keys the radio too. *)
function OpenLogRefusal(aTransmitting, aSendingCW: boolean): TOpenLogRefusal;

(* IS THE CHOSEN FILE THE ONE ALREADY OPEN? Both are expanded first, and the
  comparison follows the platform's file-name case rule -- C:\Logs\A.db and
  c:\logs\a.DB are one file on Windows and two on Linux. An empty name on
  either side is never "the same". *)
function IsSameLogFile(const aChosen, aCurrent: string): boolean;

(* THE CHILD'S ARGUMENTS, in order:

     <log file>                       first, because /IMPORTLOG and the
                                      headless arms still read ParamStr(1)
     --settings ... / --lang ...      carried forward from the parent, in
                                      either spelling, so the station comes
                                      back on the settings and language it
                                      left with
     --wait-for-instance=<pid>        exactly once

  Everything else on the parent's line is DROPPED: the old contest file, any
  headless switch, and a wait switch the parent itself was started with.

  NO QUOTING. RunProgram hands each element to TProcess.Parameters, which
  quotes an element containing a space (fcl-process win/process.inc,
  MaybeQuoteIfNotQuoted); on Unix the elements go to exec unchanged. A quote
  added here would arrive as part of the file name. *)
function BuildRelaunchArguments(const aParentArgs: array of string;
                                const aLogFile: string;
                                aParentPid: cardinal): TRelaunchArgs;

(* WAS THIS RUN STARTED BY OPEN LOG? True, with the parent's pid, when one
  argument is WAIT_FOR_INSTANCE_SWITCH followed by a decimal number. A
  malformed value (empty, not a number, too large) answers False: the child
  then behaves as an ordinary start, which is the safe reading. *)
function WaitForInstanceRequested(const aArgs: array of string;
                                  out aParentPid: cardinal): boolean;

(* ParamStr(1)..ParamStr(ParamCount), for the two routines above. *)
function CommandLineArguments: TRelaunchArgs;

(* THE ONE-SHOT REQUEST. The Open Log arm records what to start and then calls
  ExitProgram; tr4w_ShutDown asks TakeRelaunchRequest after the log is closed
  and starts it. Any other exit finds no request and relaunches nothing. *)
procedure RequestRelaunch(const aExecutable: string; const aArgs: TRelaunchArgs);
function TakeRelaunchRequest(out aExecutable: string;
                             out aArgs: TRelaunchArgs): boolean;

implementation

uses
   SysUtils;

var
   GRelaunchExecutable: string = '';
   GRelaunchArgs: TRelaunchArgs = nil;
   GRelaunchRequested: boolean = False;

function OpenLogRefusal(aTransmitting, aSendingCW: boolean): TOpenLogRefusal;
begin
   if aTransmitting then
      begin
      Result := olrTransmitting;
      end
   else if aSendingCW then
      begin
      Result := olrSendingCW;
      end
   else
      begin
      Result := olrNone;
      end;
end;

function IsSameLogFile(const aChosen, aCurrent: string): boolean;
var
   chosen:  string;
   current: string;
begin
   Result := False;
   if (aChosen = '') or (aCurrent = '') then
      begin
      Exit;
      end;

   (* The UnicodeString overload of ExpandFileName (finah.inc is included for
     both string types), so nothing narrows. *)
   chosen  := ExpandFileName(aChosen);
   current := ExpandFileName(aCurrent);

   if FileNameCaseSensitive then
      begin
      Result := chosen = current;
      end
   else
      begin
      Result := UnicodeSameText(chosen, current);
      end;
end;

(* Is aArg the switch aName, in its `--name=value` spelling? *)
function IsJoinedSwitch(const aArg, aName: string): boolean;
begin
   Result := UnicodeSameText(Copy(aArg, 1, Length(aName) + 1), aName + '=');
end;

procedure AppendArg(var aArgs: TRelaunchArgs; const aValue: string);
begin
   SetLength(aArgs, Length(aArgs) + 1);
   aArgs[High(aArgs)] := aValue;
end;

function BuildRelaunchArguments(const aParentArgs: array of string;
                                const aLogFile: string;
                                aParentPid: cardinal): TRelaunchArgs;
var
   i:   integer;
   arg: string;
begin
   Result := nil;
   AppendArg(Result, aLogFile);

   i := Low(aParentArgs);
   while i <= High(aParentArgs) do
      begin
      arg := aParentArgs[i];

      (* --settings <path>, --lang <code>, -l <code>: the switch and the value
        after it. The same three names uProgramMain.FirstNonSwitchArgument
        treats as taking a value, so the two agree on what a value is. A
        switch with nothing after it is dropped: the parent read nothing from
        it either. *)
      if UnicodeSameText(arg, '--settings') or
         UnicodeSameText(arg, '--lang')     or
         UnicodeSameText(arg, '-l')         then
         begin
         if i < High(aParentArgs) then
            begin
            AppendArg(Result, arg);
            AppendArg(Result, aParentArgs[i + 1]);
            end;
         Inc(i, 2);
         Continue;
         end;

      if IsJoinedSwitch(arg, '--settings') or IsJoinedSwitch(arg, '--lang') then
         begin
         AppendArg(Result, arg);
         end;

      Inc(i);
      end;

   AppendArg(Result, WAIT_FOR_INSTANCE_SWITCH + string(IntToStr(aParentPid)));
end;

(* A decimal cardinal, digits only. Written out rather than TryStrToDWord,
  which takes AnsiString and would narrow the argument; and stricter than Val,
  which accepts a '$' hex prefix and leading spaces. *)
function TryParsePid(const s: string; out aPid: cardinal): boolean;
var
   i:     integer;
   value: QWord;
begin
   Result := False;
   aPid   := 0;
   if (s = '') or (Length(s) > 10) then
      begin
      Exit;
      end;

   value := 0;
   for i := 1 to Length(s) do
      begin
      if (s[i] < '0') or (s[i] > '9') then
         begin
         Exit;
         end;
      value := value * 10 + QWord(Ord(s[i]) - Ord('0'));
      end;

   if value > High(cardinal) then
      begin
      Exit;
      end;

   aPid   := cardinal(value);
   Result := True;
end;

function WaitForInstanceRequested(const aArgs: array of string;
                                  out aParentPid: cardinal): boolean;
var
   i: integer;
begin
   Result     := False;
   aParentPid := 0;
   for i := Low(aArgs) to High(aArgs) do
      begin
      if UnicodeSameText(Copy(aArgs[i], 1, Length(WAIT_FOR_INSTANCE_SWITCH)),
                         WAIT_FOR_INSTANCE_SWITCH) then
         begin
         Result := TryParsePid(Copy(aArgs[i], Length(WAIT_FOR_INSTANCE_SWITCH) + 1,
                                    MaxInt),
                               aParentPid);
         Exit;
         end;
      end;
end;

function CommandLineArguments: TRelaunchArgs;
var
   i: integer;
begin
   Result := nil;
   SetLength(Result, ParamCount);
   for i := 1 to ParamCount do
      begin
      Result[i - 1] := ParamStr(i);
      end;
end;

procedure RequestRelaunch(const aExecutable: string; const aArgs: TRelaunchArgs);
begin
   GRelaunchExecutable := aExecutable;
   GRelaunchArgs       := Copy(aArgs);
   GRelaunchRequested  := True;
end;

function TakeRelaunchRequest(out aExecutable: string;
                             out aArgs: TRelaunchArgs): boolean;
begin
   Result      := GRelaunchRequested;
   aExecutable := GRelaunchExecutable;
   aArgs       := GRelaunchArgs;

   (* ONE SHOT: a second exit path reaching tr4w_ShutDown must not start a
     second child. *)
   GRelaunchRequested  := False;
   GRelaunchExecutable := '';
   GRelaunchArgs       := nil;
end;

end.

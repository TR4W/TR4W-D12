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
unit uVerificationChecks;
{$I tr4w.inc}

(*
  "IS EVERYTHING ALL RIGHT?" -- ASKED ON PURPOSE.

  NY4I, 2026-09-11: *"it would be handy to have something on the tools menu to
  essentially say run verification checks or something like that. And one of
  the things that we do right now is just do an integrity verification on the
  database."*

  ------------------------------------------------------------------------
  A FRAMEWORK WITH ONE CHECK IN IT, NOT A MENU ITEM WIRED TO ONE ROUTINE
  ------------------------------------------------------------------------

  There is exactly one check today -- the contest log's integrity check -- and
  building it as a list anyway is deliberate rather than speculative. The
  questions an operator wants answered before a contest are all the same SHAPE:
  a name, a verdict, and a sentence explaining it. The CTY.DAT vintage, whether
  the settings file is writable, whether the configured serial ports still
  exist, whether the log's own counts agree with what the program holds in
  memory -- each is a function returning that triple, and each would otherwise
  arrive as a second menu item with its own dialog.

  ------------------------------------------------------------------------
  THE RULES A CHECK FOLLOWS
  ------------------------------------------------------------------------

  IT IS READ-ONLY. A check observes and reports; it never repairs, disables or
  reconfigures anything. That is what makes running them all, at any moment, a
  safe thing for an operator to do mid-contest.

  IT NEVER RAISES. RunAllChecks catches whatever escapes and turns it into a
  failed result carrying the exception's own text, because a diagnostic that
  crashes the program is worse than no diagnostic.

  IT KNOWS NOTHING ABOUT THE SCREEN. This unit has no LCL reference and returns
  data; uVerificationForm renders it. That is what lets the checks be called
  from a test, and it is why the results are a plain array rather than rows
  poked into a grid.
*)

interface

type
   (* One check's verdict.  Passed is the headline; Detail is the sentence the
     operator reads, and it is set whether the check passed or failed -- "the
     log is sound" is the answer that was asked for just as much as the
     failure is. *)
   TVerificationResult = record
      Name: string;
      Passed: boolean;
      Detail: string;
   end;

   TVerificationResults = array of TVerificationResult;

   (* A check: its own name is not its business, so the registration carries
     the name and this returns only the verdict. *)
   TVerificationCheckFunc = function(out aDetail: string): boolean;

(* Add a check.  Called from an initialization section, so the list is built by
  the units that own the checks rather than by a table here that would have to
  name them all. *)
procedure RegisterVerificationCheck(const aName: string;
                                    const aCheck: TVerificationCheckFunc);

(* Every registered check, in registration order, each having been run.  Never
  raises: a check that throws comes back as a failure whose Detail is the
  exception text. *)
function RunAllVerificationChecks: TVerificationResults;

(* How many checks are registered.  For the form, which says what it is about
  to do before it does it. *)
function VerificationCheckCount: integer;

implementation

uses
   SysUtils,
   uLogStore;   // LogStoreCheckIntegrity -- the first and, today, only check

type
   TRegisteredCheck = record
      Name: string;
      Check: TVerificationCheckFunc;
   end;

var
   GChecks: array of TRegisteredCheck;


procedure RegisterVerificationCheck(const aName: string;
                                    const aCheck: TVerificationCheckFunc);
var
   n: integer;
begin
   if not Assigned(aCheck) then
      begin
      Exit;
      end;

   n := Length(GChecks);
   SetLength(GChecks, n + 1);
   GChecks[n].Name := aName;
   GChecks[n].Check := aCheck;
end;


function VerificationCheckCount: integer;
begin
   Result := Length(GChecks);
end;


function RunAllVerificationChecks: TVerificationResults;
var
   i: integer;
   detail: string;
begin
   SetLength(Result, Length(GChecks));
   for i := 0 to High(GChecks) do
      begin
      Result[i].Name := GChecks[i].Name;
      detail := '';
      try
         Result[i].Passed := GChecks[i].Check(detail);
         Result[i].Detail := detail;
      except
         (* THE CHECK ITSELF BROKE, which is a finding and not a reason to take
           the program down with it. *)
         on E: Exception do
            begin
            Result[i].Passed := False;
            Result[i].Detail := 'The check could not be completed: '
                                + E.ClassName + ': ' + E.Message;
            end;
      end;
      end;
end;


(* THE FIRST CHECK.

  A one-line adapter rather than registering LogStoreCheckIntegrity directly,
  because the log store's signature is its own and this unit should not be the
  reason it can never change. *)
function CheckContestLogIntegrity(out aDetail: string): boolean;
begin
   Result := LogStoreCheckIntegrity(aDetail);
end;


initialization
   RegisterVerificationCheck('Contest log database integrity',
                             @CheckContestLogIntegrity);

end.

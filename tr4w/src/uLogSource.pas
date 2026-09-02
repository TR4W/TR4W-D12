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

(* WHERE AN EXPORT READS ITS QSOs FROM -- STEP B3, THE EQUIVALENCE GATE.

  TR4W has two copies of the log now: the binary .TRW it has always written and
  the SQLite database written beside it (uLogShadow). B3 asks the one question
  that decides whether the second can replace the first:

    EXPORTED FROM THE DATABASE, DOES THE PROGRAM PRODUCE THE SAME BYTES?

  The golden corpus is what answers it. Its 26 reference artifacts were written
  by D7 -- A DIFFERENT PROGRAM -- and that independence is the whole value of
  the oracle, so the references do not change here and must never be rebaselined
  from our own output. Only the SOURCE changes, and the corpus is run BOTH ways:
  two independent readers agreeing on 26 byte-exact files is the proof, and it
  is available only while both readers exist.

  WHY A CURSOR AND NOT A LIST. The thirteen export loops in PostUnit are shaped

      if not OpenLogFile then Exit;
      ReadVersionBlock;
      while ReadLogFile do          -- fills the TempRXData global
         if GoodLookingQSO then ...

  and several of them accumulate scoring inline, with gotos. Handing them an
  array would mean rewriting every loop -- and then a difference in the output
  could have come from the rewrite rather than from the store, which is exactly
  what this step exists to rule out. So the shape is preserved exactly and only
  the three verbs are repointed. A difference in the bytes can then have come
  from ONE place.

  THE BINARY ARM IS NOT A COPY of MainUnit's cursor, it CALLS it. There is one
  implementation of reading a .TRW and it stays where it is.

  This unit is deliberately small and dumb: no filtering, no ordering decisions,
  no GoodLookingQSO. Those belong to the caller and are identical either way. *)
unit uLogSource;

{$I tr4w.inc}

interface

uses
   VC;

type
   (* lsBinary -- the .TRW, exactly as before, and the default.
      lsDatabase -- the SQLite log written beside it. *)
   TLogSourceKind = (lsBinary, lsDatabase);

var
   (* THE DEFAULT IS THE BINARY LOG AND MUST STAY THAT WAY until B3 is green.
      An operator's export cannot depend on a store nothing has verified yet.
      Set from the /EXPORTDB switch, which exists for the corpus. *)
   LogSourceKind: TLogSourceKind = lsBinary;

(* Opens the log for a sequential read.  False if it cannot be read at all. *)
function LogSourceOpen: boolean;

(* Positions at the first QSO -- the ReadVersionBlock equivalent.  Call after
  LogSourceOpen and before the first LogSourceNext. *)
procedure LogSourceRewind;

(* Reads the next QSO.  False at the end.  Fills aQso with zeroes when it
  returns False, so a caller that ignores the result reads a blank rather than
  the previous record again. *)
function LogSourceNext(out aQso: ContestExchange): boolean;

procedure LogSourceClose;

(* The file the current source reads -- for diagnostics and for the corpus
  driver to report which store produced an artifact. *)
function LogSourceDescription: string;

implementation

uses
   (* NOT uLogShadow: that unit is deleted at B5 and this one is not, so it
      must not depend on it. The database's name comes from the rule in
      uLogDatabase, which is where it outlives the shadow. *)
   SysUtils, MainUnit, uLogDatabase, uLogRepository,
   (* TempRXData, which is declared in PostUnit's INTERFACE and is what
      MainUnit.ReadLogFile fills. PostUnit uses this unit in ITS
      implementation, so the pair is circular -- normal in this tree and
      legal because both edges are implementation-section. *)
   PostUnit;

(* The SQLite log beside the current binary log.  One call, so the two
  arms below and the diagnostic cannot name different files. *)
function DatabasePath: string;
begin
   Result := LogDatabaseFileName(string(StrPas(TR4W_LOG_FILENAME)));
end;

var
   GDatabase: TLogDatabase = nil;
   GRepository: TLogRepository = nil;

function LogSourceOpen: boolean;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         LogSourceClose;
         try
            GDatabase := TLogDatabase.Create;
            (* The name rule lives in uLogDatabase. Deriving it a
               second time here is how the two would come to disagree. *)
            GDatabase.Open(DatabasePath);
            GRepository := TLogRepository.Create(GDatabase);
            Result := True;
         except
            on E: Exception do
               begin
               (* REPORTED, NOT SILENTLY FALLEN BACK TO THE BINARY LOG. A
                  fallback here would make a corpus run that was supposed to
                  prove the database quietly prove the .TRW again, and pass. *)
               if logger <> nil then
                  begin
                  logger.Error('[LogSource] cannot open the SQLite log %s: ' +
                               '%s -- %s. The export will produce nothing; it ' +
                               'will NOT fall back to the binary log.',
                               [DatabasePath, E.ClassName, E.Message]);
                  end;
               LogSourceClose;
               Result := False;
               end;
            end;
         end;
      else
         begin
         Result := OpenLogFile;
         end;
      end;
end;

procedure LogSourceRewind;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         if GRepository <> nil then
            begin
            GRepository.OpenSequentialRead;
            end;
         end;
      else
         begin
         ReadVersionBlock;
         end;
      end;
end;

function LogSourceNext(out aQso: ContestExchange): boolean;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         Result := (GRepository <> nil) and GRepository.ReadNext(aQso);
         end;
      else
         begin
         (* MainUnit's ReadLogFile reads into the TempRXData global rather than
            into a parameter, which is why this copies. Every caller passes
            TempRXData itself, so the copy is to the same record and costs
            nothing; a caller that passes something else gets what it asked
            for instead of a hidden write to a global. *)
         Result := ReadLogFile;
         aQso := TempRXData;
         end;
      end;
end;

procedure LogSourceClose;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         if GRepository <> nil then
            begin
            GRepository.CloseSequentialRead;
            end;
         FreeAndNil(GRepository);
         FreeAndNil(GDatabase);
         end;
      else
         begin
         CloseLogFile;
         end;
      end;
end;

function LogSourceDescription: string;
begin
   case LogSourceKind of
      lsDatabase: Result := 'SQLite: ' + DatabasePath;
      else        Result := 'binary: ' + string(AnsiString(TR4W_LOG_FILENAME));
      end;
end;

end.

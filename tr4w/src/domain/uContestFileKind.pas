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

(* WHAT KIND OF FILE DID THE OPERATOR JUST CHOOSE AS A CONTEST?

  THIS EXISTS BECAUSE THE ANSWER USED TO BE ASSUMED. Whatever arrived in
  TR4W_CFG_FILENAME -- from the New Contest dialog or from the command line --
  went straight to the line-based config parser. That was safe only while the
  dialog offered nothing but .cfg files. It now offers .db as its PRIMARY
  filter, because a .db is what a contest is after phase E2, and an operator
  can browse to anything at all.

  TWO FAILURES, MEASURED 2026-09-02, BOTH SILENT-LOOKING:

    a .db  -- the parser reads the SQLite header as line one, sees it is not
              MY CALL, and raises a modal warning BEFORE THE MAIN WINDOW
              EXISTS. NY4I: "The program does not show the UI but is still
              running." It had not hung; it was waiting on a dialog with
              nothing to show it against.

    a .png -- "appeared to die quietly" (NY4I). Binary bytes through a text
              parser produce either that same invisible modal or a halt, and
              in neither case is the operator told what was wrong with the
              file they picked.

  SO THE KIND IS DECIDED ONCE, BY THE BYTES, BEFORE ANYONE ACTS ON THE NAME.

  BY CONTENT AND NOT BY EXTENSION, in both directions: a log an operator
  renamed to .cfg is still a database and must not be parsed as text, and a
  text file named .db is still text. An extension is a hint that anyone can
  change; a magic header is the format saying what it is.

  A LEAF UNIT ON PURPOSE. It takes a file name and returns a value -- no
  globals, no dialog, no logging, no database layer. That is what lets it be
  unit-tested against real fixture bytes, which is the only way to know a .png
  is actually rejected. The CALLER decides what a given answer means and what
  to say about it, because only the caller knows what it wanted the file for. *)
unit uContestFileKind;

{$I tr4w.inc}

interface

type
   (* THE ORDER IS NOT MEANINGFUL and nothing may depend on it -- these are
     names, not a severity scale. *)
   TContestFileKind = (
      cfkMissing,          (* no such file, or it cannot be read at all *)
      cfkTR4WDatabase,     (* a SQLite database stamped as one of ours *)
      cfkForeignDatabase,  (* a SQLite database that is somebody else's *)
      cfkTextConfig,       (* plausibly a text .cfg -- parse it *)
      cfkUnrecognised      (* binary, and not a database. A .png lands here *)
   );

function ClassifyContestFile(const aFileName: string): TContestFileKind;

implementation

uses
   Classes, SysUtils, uLogSchema;

const
   (* The SQLite file format's own first 16 bytes, header string included and
     including its terminating zero -- sqlite.org/fileformat2.html section 1.3. *)
   SQLITE_MAGIC: array[0..15] of AnsiChar =
      ('S','Q','L','i','t','e',' ','f','o','r','m','a','t',' ','3',#0);

   (* application_id is a big-endian 32-bit word at offset 68 of the header.
     The header is always 100 bytes, so a file claiming to be SQLite and
     shorter than that is malformed rather than merely foreign. *)
   APPLICATION_ID_OFFSET = 68;
   SQLITE_HEADER_BYTES   = 100;

   (* HOW MUCH TO READ BEFORE CALLING SOMETHING TEXT. A contest .cfg's first
     line is MY CALL, so a real one declares itself immediately; this only has
     to be long enough to catch the binary formats an operator might pick by
     mistake, and every one of them -- PNG, JPEG, ZIP, EXE, PDF -- carries a
     zero byte far sooner than this. *)
   TEXT_PROBE_BYTES = 512;

function ClassifyContestFile(const aFileName: string): TContestFileKind;
var
   f:      TFileStream;
   head:   array[0..SQLITE_HEADER_BYTES - 1] of Byte;
   probe:  array[0..TEXT_PROBE_BYTES - 1] of Byte;
   got:    integer;
   i:      integer;
   appId:  LongWord;
begin
   Result := cfkMissing;

   if aFileName = '' then
      begin
      Exit;
      end;

   if not FileExists(aFileName) then
      begin
      Exit;
      end;

   try
      (* fmShareDenyNone: the database may legitimately be open already -- this
        program opens it moments later, and on a multi-op station another
        process may hold it. Asking what a file IS must never require
        exclusive access. *)
      (* AnsiString() EXPLICITLY. tr4w.inc sets {$MODESWITCH UnicodeStrings},
        so string is UnicodeString here while the RTL stream constructor
        takes the RTL string -- an implicit narrowing the build ratchet
        counts. Stated rather than left implicit, the same way
        uLogDatabase.pas:279 states it at the same boundary. *)
      f := TFileStream.Create(AnsiString(aFileName), fmOpenRead or fmShareDenyNone);
      try
         (* AN EMPTY FILE IS TEXT, not unrecognised. That is what a freshly
           created .cfg is for the moment before anything is written to it,
           and reporting "this is not a valid contest file" for one would be
           a regression against today's behaviour, which parses it to
           nothing. *)
         if f.Size = 0 then
            begin
            Result := cfkTextConfig;
            Exit;
            end;

         got := f.Read(head, SizeOf(head));

         if (got >= SizeOf(SQLITE_MAGIC)) and
            (CompareByte(head, SQLITE_MAGIC, SizeOf(SQLITE_MAGIC)) = 0) then
            begin
            if got < SQLITE_HEADER_BYTES then
               begin
               (* Claims to be SQLite and is too short to hold a header: a
                 truncated file, which is not something to hand to the
                 database layer. *)
               Result := cfkForeignDatabase;
               Exit;
               end;

            (* BIG-ENDIAN, ASSEMBLED BY HAND. The file format is big-endian and
              this program is not, so a cast over the bytes would read the id
              backwards on every machine we ship to. *)
            appId := (LongWord(head[APPLICATION_ID_OFFSET])     shl 24) or
                     (LongWord(head[APPLICATION_ID_OFFSET + 1]) shl 16) or
                     (LongWord(head[APPLICATION_ID_OFFSET + 2]) shl 8)  or
                      LongWord(head[APPLICATION_ID_OFFSET + 3]);

            (* ZERO IS ACCEPTED, and this is the one judgement call here. An
              application_id of 0 means "nobody stamped this", which is what
              every database made before we started stamping looks like --
              including logs made by earlier builds of THIS program. Refusing
              them would make an operator's existing logs unopenable to fix a
              cosmetic check. TLogDatabase takes the same view when it opens
              (it rejects only a non-zero id that is not ours), and the two
              must agree or this would pass files that then fail to open. *)
            if (appId = 0) or (appId = LOG_APPLICATION_ID) then
               begin
               Result := cfkTR4WDatabase;
               end
            else
               begin
               Result := cfkForeignDatabase;
               end;

            Exit;
            end;

         (* NOT A DATABASE. The remaining question is whether a line parser
           can make any sense of it, and a zero byte settles that: text files
           in this program do not contain one, and the binary formats an
           operator might pick all do, early. *)
         f.Position := 0;
         got := f.Read(probe, SizeOf(probe));

         Result := cfkTextConfig;

         for i := 0 to got - 1 do
            begin
            if probe[i] = 0 then
               begin
               Result := cfkUnrecognised;
               Break;
               end;
            end;
      finally
         f.Free;
      end;
   except
      (* A FILE WE CANNOT READ IS cfkMissing, not unrecognised. Locked, denied
        or vanished between the FileExists and the open -- from the caller's
        point of view there is nothing here to use, and the message for that
        is the one about a file that is not there. *)
      on E: Exception do
         begin
         Result := cfkMissing;
         end;
   end;
end;

end.

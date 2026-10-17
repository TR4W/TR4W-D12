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

(* AN APPENDER THAT KEEPS WHAT IT IS GIVEN -- to prove a report was WRITTEN
  and what it names, rather than trusting that a code path logs.

  LIFTED 2026-10-17 from uTestADIFSentExchange, where it was private, when
  Idaho's "no bonus table for this year" report (Q35) became its second
  caller. One copy, so the two cannot drift.

  USE: create it, hold it in an ILogAppender variable (the logger owns
  appenders by interface reference), AddAppender to the unit's logger with
  the level the report is written at, and RemoveAppender in a finally. *)
unit uTestLogCapture;

{$I ..\..\src\tr4w.inc}

interface

uses
   Classes,
   Log4D;

type
   TCaptureAppender = class(TLogCustomAppender)
   private
      FLines: TStringList;
   protected
      procedure DoAppend(const Message: string); override;
   public
      constructor Create(const aName: string); reintroduce;
      destructor Destroy; override;
      property Lines: TStringList read FLines;
   end;

implementation

constructor TCaptureAppender.Create(const aName: string);
begin
   inherited Create(aName);
   FLines := TStringList.Create;
end;

destructor TCaptureAppender.Destroy;
begin
   (* inherited FIRST: the base destructor closes the appender, which writes
      its footer through DoAppend -- into FLines, which must still exist. *)
   inherited Destroy;
   FLines.Free;
end;

procedure TCaptureAppender.DoAppend(const Message: string);
begin
   FLines.Add(Message);
end;

end.

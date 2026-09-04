{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
 }
unit uLogSearch;
{$I tr4w.inc}

(* THE SEAM, AND IT DID ITS JOB.

  This unit held the Log Search window: a CreateModalDialog template, controls
  built with CreateStatic / CreateEdit / CreateButton, a raw list view from
  CreateEditableLog, and a DlgProc with five labels and two gotos driving a
  linear scan of the whole log.

  Its own header said what this moment would look like -- "THE SEAM for the
  Win32-to-LCL migration (Phase 1, 2026-08-17): the caller no longer knows this
  is a Win32 modal dialog, only that the window opens. When the dialog becomes
  an LCL form, this body changes and nothing else does."

  That is what happened. The window is uLogSearchForm; MainUnit is untouched.

  THE UNIT SURVIVES ONLY AS THIS FORWARD. It can go the moment MainUnit calls
  the form directly, and there is no reason to keep it beyond that. *)

interface

procedure ShowLogSearch;

implementation

uses
   uLogSearchForm;

procedure ShowLogSearch;
begin
   ShowLogSearchForm;
end;

end.

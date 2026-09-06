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
unit uDialogs;

(* ONE DIALOG, ON THE LCL'S OWN CLASS.

   This unit was 664 lines and exported one function that anything called.  The
   rest was a hand-transcribed slice of the Win32 shell and common-dialog
   headers -- TBrowseInfo, ITEMIDLIST, SHBrowseForFolder, ShellExecuteEx's
   SEE_MASK_* set, the CSIDL_* folder ids, both TOpenFilename record layouts and
   forty OFN_* flags -- with every declaration that used them commented out.

   What went, and why it is the direction rather than tidying:

     * four comdlg32.dll bindings plus a LoadLibrary/GetProcAddress pair for a
       fifth.  TOpenDialog is the LCL's own class and needs none of them, which
       is what "no new direct calls into a DLL" is protecting.
     * PAnsiChar in and out.  The caller used to build a filter as
       'Description'#0'*.ext'#0#0 by hand; TOpenDialog takes 'Description|*.ext'.
     * TR4W_OFNHookProc, an OFN_ENABLEHOOK callback that relabelled the common
       dialog's Help button to "Start a new contest".  Its assignment was
       commented out, so it had not run in this tree, and the flag set that
       enables it (OpenCFGFlags) had no caller.  If that button is wanted back
       it is a designed form, not a hook into a system dialog.

   The Flags parameter is gone with the OFN_* constants: between them the two
   call sites asked for HIDEREADONLY and ENABLESIZING -- both already how
   TOpenDialog behaves -- and one asked for FILEMUSTEXIST, which is the boolean
   below. *)

{$I tr4w.inc}
{$IMPORTEDDATA OFF}

interface

uses
  VC;                  { FileNameType -- the fixed AnsiChar path buffer both
                         callers keep their answer in }

(* THE PATH COMES BACK IN A FileNameType, not as a string, because that is what
   both callers already hold: TR4W_EXECONFIGFILE_FILENAME and TR4W_ADIF_FILENAME
   are globals of that type and are read as ASCIIZ elsewhere.  Converting them
   is a separate change with a wider blast radius than this one.

   aFilter is TOpenDialog's form: 'Description|mask', '|' between entries.
   aMustExist maps to ofFileMustExist; the other two flags the old call sites
   passed (HIDEREADONLY, ENABLESIZING) are already TOpenDialog's behaviour. *)
function OpenFileDlg(const aTitle, aFilter: string;
                     var aFileName: FileNameType;
                     const aMustExist: boolean): boolean;

implementation

uses
  SysUtils,
  LCLType,             { TTranslateString -- the LCL's own string, see below }
  Dialogs,             { TOpenDialog }
  Forms,               { Application -- the dialog parents itself to the form }
  uAnsiStr;            { StrPLCopy over PAnsiChar; SysUtils' is PWideChar }

function OpenFileDlg(const aTitle, aFilter: string;
                     var aFileName: FileNameType;
                     const aMustExist: boolean): boolean;
var
   dlg: TOpenDialog;
begin
   Result := False;

   dlg := TOpenDialog.Create(Application);
   try
      (* EXPLICIT AT THE BOUNDARY.  The LCL is compiled WITHOUT the
        UnicodeStrings mode switch and every TR4W unit with it, so its `string`
        is an AnsiString and ours is a UnicodeString -- exactly the seam the
        Caption assignments name.  Saying so is the difference between a
        conversion someone chose and one the compiler did quietly. *)
      dlg.Title := TTranslateString(aTitle);
      dlg.Filter := AnsiString(aFilter);
      dlg.Options := dlg.Options + [ofPathMustExist, ofEnableSizing,
                                    ofHideReadOnly];
      if aMustExist then
         begin
         dlg.Options := dlg.Options + [ofFileMustExist];
         end;

      if not dlg.Execute then
         begin
         Exit;
         end;

      { Cleared first: the caller reads this as ASCIIZ, and a shorter path over
        a longer one would otherwise leave the old tail behind the terminator. }
      FillChar(aFileName, SizeOf(aFileName), 0);
      uAnsiStr.StrPLCopy(@aFileName[0], AnsiString(dlg.FileName),
                         High(aFileName));
      Result := True;
   finally
      dlg.Free;
   end;
end;

end.

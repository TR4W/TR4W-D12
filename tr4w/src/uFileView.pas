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
unit uFileView;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
uses
  VC,
  TF,
//  mapi,
//  CommCtrl,
  uMenu,
  Windows,
  Tree,
  LogWind,
  PostUnit,
  Messages,
  uTR4WStrings,
  uAnsiStr;

const
  MAPI_DIALOG                           = $00000008; { Display a send note UI       }
  MAPI_UNREAD                           = $00000001;
  MAPI_RECEIPT_REQUESTED                = $00000002;
  MAPI_SENT                             = $00000004;

  MAPI_ORIG                             = 0; { Recipient is message originator          }

  MAPI_TO                               = 1; { Recipient is a primary recipient         }

  MAPI_CC                               = 2; { Recipient is a copy recipient            }

  MAPI_BCC                              = 3; { Recipient is blind copy recipient        }

  MAPI_LOGON_UI                         = $00000001; { Display logon UI             }
  MAPI_NEW_SESSION                      = $00000002; { Don't use shared session     }
  SUCCESS_SUCCESS                       = 0;
type

  Flags = Cardinal;
  LHANDLE = Cardinal;
  PLHANDLE = ^Cardinal;

  PMapiRecipDesc = ^TMapiRecipDesc;
{$EXTERNALSYM MapiRecipDesc}
  MapiRecipDesc = packed record
    ulReserved: Cardinal; { Reserved for future use                  }
    ulRecipClass: Cardinal; { Recipient class                          }
                                { MAPI_TO, MAPI_CC, MAPI_BCC, MAPI_ORIG    }
    lpszName: LPSTR; { Recipient name                           }
    lpszAddress: LPSTR; { Recipient address (optional)             }
    ulEIDSize: Cardinal; { Count in bytes of size of pEntryID       }
    lpEntryID: Pointer; { System-specific recipient reference      }
  end;
  TMapiRecipDesc = MapiRecipDesc;

  PMapiFileDesc = ^TMapiFileDesc;
  MapiFileDesc = packed record
    ulReserved: Cardinal; { Reserved for future use (must be 0)     }
    flFlags: Cardinal; { Flags                                   }
    nPosition: Cardinal; { character in text to be replaced by attachment }
    lpszPathName: LPSTR; { Full path name of attachment file       }
    lpszFileName: LPSTR; { Original file name (optional)           }
    lpFileType: Pointer; { Attachment file type (can be lpMapiFileTagExt) }
  end;
  TMapiFileDesc = MapiFileDesc;

  MapiMessage = packed record
    ulReserved: Cardinal; { Reserved for future use (M.B. 0)       }
    lpszSubject: LPSTR; { Message Subject                        }
    lpszNoteText: LPSTR; { Message Text                           }
    lpszMessageType: LPSTR; { Message Class                          }
    lpszDateReceived: LPSTR; { in YYYY/MM/DD HH:MM format             }
    lpszConversationID: LPSTR; { conversation thread ID                 }
    flFlags: Cardinal; { unread,return receipt                  }
    lpOriginator: PMapiRecipDesc; { Originator descriptor                  }
    nRecipCount: Cardinal; { Number of recipients                   }
    lpRecips: PMapiRecipDesc; { Recipient descriptors                  }
    nFileCount: Cardinal; { # of file attachments                  }
    lpFiles: PMapiFileDesc; { Attachment descriptors                 }
  end;
  TMapiMessage = MapiMessage;

  TFNMapiLogOff = function(lhSession: LHANDLE; ulUIParam: Cardinal; flFlags: Flags;
    ulReserved: Cardinal): Cardinal stdcall;

  TMAPISendDocuments = function(ulUIParam: Cardinal; lpszDelimChar: LPSTR; lpszFilePaths: LPSTR; lpszFileNames: LPSTR; ulReserved: Cardinal): Cardinal; stdcall;

  TFNMapiLogOn = function(ulUIParam: Cardinal; lpszProfileName: LPSTR;
    lpszPassword: LPSTR; flFlags: Cardinal; ulReserved: Cardinal;
    lplhSession: PLHANDLE): Cardinal stdcall;

  TFNMapiSendMail = function
    (
    lhSession: LHANDLE;
    ulUIParam: Cardinal;
    var lpMessage: TMapiMessage;
//    lpRecips: PMapiRecipDesc;
//    Files: MapiFileDesc;
    flFlags: Flags;
    ulReserved: Cardinal
    ): Cardinal stdcall;

(* THE RICH-EDIT STREAMING MACHINERY IS DELETED, not ported (2026-09-01).

   The viewer created a RICHED32 control, built an _editstream record with a
   callback, and pushed the file through EM_STREAMIN with SF_TEXT -- a
   rich-text control used exclusively to display PLAIN TEXT.
   ui/lcl/uFileViewForm shows the same file in a read-only TMemo, so the
   stream record, TEditStreamCallBack, OpenCallback (a wrapper round
   ReadFile), the
   SF_/EM_/ReadError constants and the RichEditViewer handle all go with it.

   MainUnit.RichEditOperation STAYS.  This window was one of its two callers
   and no longer takes a reference on RICHED32.DLL; the MMTTY window is the
   other and still does. *)

procedure SendMail(Address: PAnsiChar; BugReport: boolean);

var
  MAPISendDocuments                     : TMAPISendDocuments;
//  MapiLogOn                             : TFNMapiLogOn;
//  MapiLogOff                            : TFNMapiLogOff;
  MapiSendMail                          : TFNMapiSendMail;


// the full-log viewer.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowFullLog;

implementation

uses MainUnit, uFileViewForm;

procedure SendMail(Address: PAnsiChar; BugReport: boolean);
var
  module                                : HWND;
  lpMessage                             : TMapiMessage;
  Files                                 : array[0..3] of MapiFileDesc;

  lpRecips                              : TMapiRecipDesc;
  TempBuffer                            : array[0..63] of AnsiChar;
  MapiResult                            : Cardinal;
begin
  module := LoadLibrary('Mapi32.dll');
  if module <> 0 then
     begin
     @MapiSendMail := GetProcAddress(module, 'MAPISendMail');
     Windows.ZeroMemory(@lpMessage, SizeOf(TMapiMessage));
     Windows.ZeroMemory(@lpRecips, SizeOf(TMapiRecipDesc));
     Windows.ZeroMemory(@Files, SizeOf(Files));

     lpMessage.lpRecips := @lpRecips;
     lpMessage.lpFiles := @Files;

     if BugReport then
        begin
        {
      lpMessage.lpszSubject := '[Bug Report] ' + TR4W_CURRENTVERSION;
      TF.Format(wsprintfBuffer, 'Version: ' + TR4W_CURRENTVERSION + ' (' + TR4W_CURRENTVERSIONDATE + ')'#13#10'OS: %u.%u %s'#13#10'Attached 3 files.'#13#10#13#10'Description:'#13#10, tr4w_osverinfo.dwMajorVersion, tr4w_osverinfo.dwMinorVersion, tr4w_osverinfo.szCSDVersion);
      lpMessage.lpszNoteText := wsprintfBuffer;
      lpMessage.nFileCount := 3;

      Files[0].lpszPathName := TR4W_POS_FILENAME;
      Files[1].lpszPathName := TR4W_CFG_FILENAME;
      Files[2].lpszPathName := TR4W_INI_FILENAME;
}
        end
     else
        begin
        lpMessage.lpszSubject := @MyCall[1];

        lpMessage.nFileCount := 1;
        Files[0].lpszPathName := PreviewFileNameAddress;
        end;

     Files[0].nPosition := ULONG($FFFFFFFF);

     lpMessage.nRecipCount := 1;
     lpMessage.flFlags := MAPI_UNREAD;
     TF.Format(TempBuffer, 'SMTP:%s', Address);
     lpRecips.lpszAddress := TempBuffer;
     lpRecips.ulRecipClass := MAPI_TO;

     MapiResult := MapiSendMail(0, tr4whandle, lpMessage, MAPI_LOGON_UI or MAPI_DIALOG, 0);
     if MapiResult > 1 then
        begin
        TF.Format(wsprintfBuffer, 'Send Mail Error: %u', MapiResult);
        showwarning(wsprintfBuffer);
        end;

     FreeLibrary(module);
     end;
end;

procedure ShowFullLog;
begin
   ShowFileViewWindow;
end;
end.


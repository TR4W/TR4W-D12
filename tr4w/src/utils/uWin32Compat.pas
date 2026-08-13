unit uWin32Compat;

// The Win32 declarations FPC's `windows` unit does not carry.
//
// Delphi's Winapi.Windows is a fuller header than FPC's: FPC keeps its core
// `windows` unit deliberately small and pushes the rest into the JEDI headers
// (winunits-jedi).  Pulling jwawindows in for a handful of symbols would be a
// very large dependency for no gain, and scattering per-unit {$IFDEF FPC}
// externals through the tree hides how big the gap actually is.
//
// So: everything FPC is missing lives here, in one place, where the list can be
// read at a glance -- and where it will be obvious what has to be re-checked if
// the FPC version ever moves.
//
// The whole unit is EMPTY under Delphi.  It declares nothing Delphi already
// has, so a unit that uses it gets identical symbols on both compilers and the
// call sites carry no conditionals at all.
//
// Two rules for anything added here:
//
//   1. Import the W entry point explicitly, by name.  A generic import name is
//      exactly the silent A/W binding that cost this project a release once
//      (GetPrivateProfileString bound to W, wrote UTF-16 into an AnsiChar
//      buffer, and TR4WServer rejected every client -- 1bea7af4).
//
//   2. Match Delphi's declaration, not a convenient one.  These exist so the
//      SAME source compiles both ways; a signature that differs from
//      Winapi.Windows would compile here and mean something else there.

{$I ..\tr4w.inc}

interface

{$IFDEF FPC}

uses
   Windows;

const
   // MAKEINTRESOURCE aliases the `windows` unit stops one short of.  Delphi's
   // Winapi.Windows declares all of these; FPC declares only the older
   // IDI_EXCLAMATION / IDI_ASTERISK / IDI_HAND spellings they alias.
   IDI_WARNING     = IDI_EXCLAMATION;
   IDI_ERROR       = IDI_HAND;
   IDI_INFORMATION = IDI_ASTERISK;

   // Device-notification flags -- see RegisterDeviceNotificationW below.
   DEVICE_NOTIFY_WINDOW_HANDLE  = $00000000;
   DEVICE_NOTIFY_SERVICE_HANDLE = $00000001;

type
   HDEVNOTIFY = Pointer;

// Show/hide a window with an animation.  Used for the previous-dupe flash.
function AnimateWindow(hWnd: HWND; dwTime: DWORD; dwFlags: DWORD): BOOL; stdcall;
   external 'user32.dll' name 'AnimateWindow';

// Serial-port arrival/removal notification, used by ComPortEnumerator.
// W explicitly: the filter passed is DEV_BROADCAST_DEVICEINTERFACE_W, and the A
// entry point would read its name field as bytes.
function RegisterDeviceNotificationW(hRecipient: THandle;
   NotificationFilter: Pointer; Flags: DWORD): HDEVNOTIFY; stdcall;
   external 'user32.dll' name 'RegisterDeviceNotificationW';

function UnregisterDeviceNotification(Handle: HDEVNOTIFY): BOOL; stdcall;
   external 'user32.dll' name 'UnregisterDeviceNotification';

{$ENDIF}

implementation

end.

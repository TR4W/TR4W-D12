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
unit uRadio12;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  Windows,
  Messages,
  LogRadio,
  Tree;


implementation
uses
  LOGSUBS2,
  MainUnit;

// One mode label: flat, left-aligned, in the dialog's own font, four pixels to
// the right of the VFO frequency static it belongs to.
procedure CreateModeLabel(const aParent: HWND; const aId: integer; const aTop: integer);
const
   VFO_LEFT   = 50;    // the VFO statics' X
   VFO_WIDTH  = 135;   // and their width
   VFO_HEIGHT = 23;    // CreateStatic's fixed height
   GAP        = 4;
   MODE_WIDTH = 55;
var
  h: HWND;
begin
   h := Windows.CreateWindowA('STATIC', '',
      WS_CHILD or WS_VISIBLE or SS_LEFT,
      VFO_LEFT + VFO_WIDTH + GAP, aTop, MODE_WIDTH, VFO_HEIGHT,
      aParent, aId, hInstance, nil);

   Windows.SendMessage(h, WM_SETFONT,
      Windows.SendMessage(aParent, WM_GETFONT, 0, 0), 1);
end;

end.


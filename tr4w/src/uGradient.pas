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
unit uGradient;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
uses
  (* LCLIntf for GradientFill and GetSysColor, LCLType for HDC / TTriVertex /
    the GRADIENT_FILL_* modes. Windows is gone with the msimg32 loading
    (2026-09-08). *)
  LCLIntf,
  LCLType,
  Graphics,   (* GetRValue / GetGValue / GetBValue, and the LCL's ColorToRGB *)
  Types,      (* TRect *)
  VC;
type
  tcolor = -$7FFFFFFF - 1..$7FFFFFFF;
  // The definition of the TTriVertex structure in Windows.pas is
  // incorrect.
  // � Windows.pas ��������� TTriVertex � �������.
  TTriVertex = packed record
    X: LONGINT;
    Y: LONGINT;
    Red: {Smallint} Word;
    Green: {Smallint} Word;
    Blue: {Smallint} Word;
    Alpha: Smallint;
  end;
  // A genuine gap in FPC's `windows` unit rather than a behavioural
  // difference: the Win32 API has GRADIENT_RECT and Delphi's Winapi.Windows
  // declares it, FPC does not.  It is simply the index pair naming which two
  // vertices GradientFill should span, and the SDK defines it as two ULONGs.
  // Declared here for the same reason TTriVertex above is -- locally, so the
  // Delphi build keeps using the RTL's own declaration.
  (* TGradientRect was declared here as two ULONGs. LCLType declares it --
    `TGradientRect = GRADIENTRECT` -- for every widget set, so the local copy
    is gone and there is one definition again (2026-09-08). *)

  (* TGradientFill and GradientFillFunction stood here -- the signature of the
    DLL export and the pointer it was loaded into. Both went with the
    initialization section; LCLIntf declares the function itself. *)
type
  TGradientDirection = (gdHorizontal, gdVertical);
(* HDC, NOT HWND. This declared its first parameter as a window handle and
  was never given one: every caller passes a DEVICE CONTEXT -- MainUnit's dc,
  PCDRAWITEMSTRUCT^.HDC, and uRemMultsForm's grdMults.Canvas.Handle -- and it
  hands the value straight to GradientFillFunction, whose first argument is an
  HDC. The two are the same width, so nothing ever complained. *)
function GradientRect(canvashandle: HDC; const ARect: TRect; Color1, Color2: tcolor; Direction: TGradientDirection): boolean;
function ColorToRGB(Color: tcolor): Cardinal {LONGINT};
function InitTriVertex(XPos, YPos: integer; Color: tcolor): TTriVertex;
implementation

(* An msimg32.dll name constant stood here, in a `const` section with nothing
  else in it. Nothing loads that library now -- see GradientRect -- so the
  section goes with it. *)
type
  TRGB = record
    r, g, b: Byte;
  end;
function GetRGB(Color: tcolor): TRGB;
var
  iColor                                : tcolor;
begin
  iColor := ColorToRGB(Color);
  Result.r := GetRValue(iColor);
  Result.g := GetGValue(iColor);
  Result.b := GetBValue(iColor);
end;
function GradientRect(canvashandle: HDC; const ARect: TRect; Color1, Color2: tcolor; Direction: TGradientDirection): boolean;
// Function to initialise a TTriVertex
//const
//  Flag                             : array[TGradientDirection] of LONGINT = ($00000000 {GRADIENT_FILL_RECT_H}, $00000001 {GRADIENT_FILL_RECT_V});
var
  GRect                                 : TGradientRect;
  Vertex                                : array[0..1] of TTriVertex;
begin
  GRect.UpperLeft := 0;
  GRect.LowerRight := 1;
  if tEightBitsPerPixel then
     begin
     Color2 := Color1;
     end;
  Vertex[0] := InitTriVertex(ARect.Left, ARect.Top, Color1);
  Vertex[1] := InitTriVertex(ARect.Right, ARect.Bottom, Color2);
  (* LCLIntf.GradientFill, not a pointer fished out of a DLL.

    The LCL declares GradientFill with the SAME Win32 signature for every
    widget set (lcl\include\winapih.inc) -- DC, vertices, mesh, mode -- so
    this is the same call with the loading machinery deleted. On Windows it
    reaches the same GDI routine; elsewhere the widget set draws the gradient
    itself.

    THE MODE CONSTANTS ARE THE LCL'S NOW TOO: GRADIENT_FILL_RECT_H is 0 and
    _RECT_V is 1, which is the order TGradientDirection already had, so
    Cardinal(Direction) keeps meaning what it meant. *)
  Result := LCLIntf.GradientFill(canvashandle, @Vertex[0], 2, @GRect, 1,
                                 Longint(Direction));
end;
function ColorToRGB(Color: tcolor): Cardinal {LONGINT};
begin
  if Color < 0 then
    Result := GetSysColor(Color and $000000FF) else
                                                  begin
                                                  Result := Color;
                                                  end;
end;
function InitTriVertex(XPos, YPos: integer; Color: tcolor): TTriVertex;
var
  TempRGB                               : TRGB;
begin
  with Result do
     begin
     X := XPos;
     Y := YPos;
     Alpha := 0 {2};
     TempRGB := GetRGB(Color);
     Red := TempRGB.r shl 8;
     Green := TempRGB.g shl 8;
     Blue := TempRGB.b shl 8;
     end
end;
(* THE INITIALIZATION SECTION IS DELETED (2026-09-08). It resolved
  GdiGradientFill from gdi32 and fell back to GradientFill in msimg32.dll, by
  GetProcAddress into a function pointer. LCLIntf.GradientFill replaces both,
  so there is nothing to load, nothing to fall back to, and no window in which
  the pointer is nil. That also removes one of the tree's LoadLibrary sites. *)
end.

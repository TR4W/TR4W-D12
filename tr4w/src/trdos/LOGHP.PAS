{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit LOGHP;
{$I ..\tr4w.inc}

{$O+}
{$F+}
{$IMPORTEDDATA OFF}
interface
uses VC;
procedure HP;


implementation

uses Tree {, Crt};

type
  AngularModeType = (Degrees, Radians);

var
  X, Y, Z, t, LastX           : REAL;
  Mode                        : AngularModeType;
  PushableXValue              : boolean;

procedure ShowMode;

begin
  //    GoToXY (40, 1);

  if Mode = Degrees then
     begin
     Write('Degrees mode (use M to toggle)')
     end
  else
     begin
     Write('Radian mode (use M to toggle)');
     end;
end;

procedure ShowStack;

begin
  {    GoToXY (1, 1);
      ClrEol;
      WriteLn ('T = ', T:10:4);
      ClrEol;
      WriteLn ('Z = ', Z:10:4);
      ClrEol;
      WriteLn ('Y = ', Y:10:4, '          LastX = ', LastX:10:4);
      ClrEol;
      WriteLn ('X = ', X:10:4);
      ShowMode;
     }
end;

procedure DoCalculator;

var
  Key                         : Char;
  RESULT                      : integer;
  XString                     : Str20;
  temp                        : REAL;

begin
end;

procedure HPHelp;

begin
  //  WriteLn('ENTER = Carriage Return    L = LastX    ESCAPE = Clear   ');
  //  WriteLn('Q = Square root   S = Sin   C = Cos   T = Tan');
  //  WriteLn('^Q = Square   ^S = ArcSin   ^C = ArcCos   ^T = ArcTan');
  //  WriteLn('G = Log   N = Ln   ^G = 10 to the X   ^N = e to the X');
  //  WriteLn('Y = Y to the X     I = 1/X    Y = X:Y');
  //  WriteLn('X = Exit                                         HP by N6TR');
end;

procedure HP;

begin
  //    ClrScr;
  Mode := Degrees;
  //    GoToXY (1, 6);
  HPHelp;

  X := 0;
  Y := 0;
  Z := 0;
  t := 0;
  LastX := 0;
  PushableXValue := False;
  DoCalculator;
end;

begin
end.


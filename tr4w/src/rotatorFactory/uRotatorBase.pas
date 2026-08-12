{
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
}
unit uRotatorBase;

{
  THE ROTATOR FACTORY -- base class.

  WHAT IT REPLACES.  LOGSTUFF.RotorControl carries a `case ActiveRotatorType of`
  that picks a printf format per rotator, plus two special cases bolted around
  it: PSTRotator returns early because it is UDP and has no serial port, and
  AlfaSpid rewrites the buffer afterwards because its frame is binary and
  fixed-length rather than a formatted string.  That is the same shape the radio
  factory deleted -- one function that knows every model.

  THE RULE, unchanged from the radio factory and worth restating because it is
  the thing that decays first: A BASE CLASS MUST NEVER ASK WHICH ROTATOR IT IS.
  The subclass declares a trait or overrides a method; the base guards on the
  trait.  If a `if RotatorKind = ...` ever appears below this line, the design
  has been lost.

  TRANSPORT IS ABSTRACT ON PURPOSE.  A driver builds a frame and hands it to
  SendBytes; what SendBytes does -- a serial handle, a UDP socket, a test's
  capture buffer -- is the caller's business.  That is what makes every driver
  unit-testable with no hardware and no port, which is how the frames below are
  pinned byte-for-byte against the legacy formats they replace.

  HEADINGS ARE DEGREES 0..359 at this boundary.  A rotator that wants something
  else -- and AlfaSpid wants heading+360 -- converts inside its own driver,
  because that offset is a fact about the SPID protocol and not about TR4W.
}

interface

uses
   SysUtils;

type
   { What a rotator can do.  Declared per driver, never asked of a type. }
   TRotatorCapability = (
      rcTurn,        // point at an azimuth -- every rotator has this
      rcStop,        // halt mid-turn
      rcReadAzimuth  // report where it actually is
   );
   TRotatorCapabilities = set of TRotatorCapability;

   { Bytes out.  A driver never touches a port itself. }
   { HOW A DRIVER'S BYTES REACH A PORT.
     A METHOD POINTER, not a closure. It was `reference to procedure` -- an
     anonymous method -- which reads well but costs two things. It requires a
     compiler with closures (FPC 3.2.2 stable has none: `Identifier not found
     "reference"`), and it hides WHO owns the state being captured. `of object`
     says the sender is an object, which is what it always was: the one live
     rotator whose port these bytes belong on. }
   TRotatorSendProc = procedure (const aBytes: TBytes) of object;

   TRotatorBase = class abstract
   private
      FSend: TRotatorSendProc;
      FCapabilities: TRotatorCapabilities;
   protected
      { Frame for "turn to this azimuth".  The ONE thing every driver must
        answer, and the only place a protocol difference is allowed to live. }
      function TurnFrame(const aAzimuth: integer): TBytes; virtual; abstract;

      { Frame for "stop".  Empty means the rotator has no stop command, which is
        why rcStop is a declared capability rather than an assumption. }
      function StopFrame: TBytes; virtual;

      procedure SetCapabilities(const aCaps: TRotatorCapabilities);
      procedure Send(const aBytes: TBytes);

      { Helper: an ASCII frame as bytes.  Most of these protocols are printable
        commands with a CR, so this keeps the drivers to one line each. }
      function Ascii(const aText: string): TBytes;
   public
      constructor Create(const aSend: TRotatorSendProc);

      { Point the rotator.  Azimuth is normalised to 0..359 HERE so no driver
        has to, and so a caller passing 360 or -10 cannot produce a frame the
        rotator will reject. }
      procedure TurnTo(const aAzimuth: integer);
      procedure Stop;

      function Supports(const aCapability: TRotatorCapability): boolean;

      { For the UI and the log. }
      class function DisplayName: string; virtual; abstract;

      { PORT FACTS THE DRIVER OWNS, so the code that opens the port stops asking
        what kind of rotator it has.  Both replace a branch that used to live
        outside: LogCfg's `if DCU1 then BaudRate := 4800`, and RotorControl's
        early return for the UDP-only PstRotator. }
      function PreferredBaudRate: integer; virtual;
      function UsesSerialPort: boolean; virtual;
   end;

implementation

constructor TRotatorBase.Create(const aSend: TRotatorSendProc);
begin
   inherited Create;
   FSend := aSend;
   // Every rotator turns.  A driver adds to this; none has to remember to
   // declare the one capability they all share.
   FCapabilities := [rcTurn];
end;

procedure TRotatorBase.SetCapabilities(const aCaps: TRotatorCapabilities);
begin
   FCapabilities := FCapabilities + aCaps;
end;

function TRotatorBase.Supports(const aCapability: TRotatorCapability): boolean;
begin
   Result := aCapability in FCapabilities;
end;

function TRotatorBase.Ascii(const aText: string): TBytes;
var
   a: AnsiString;
   i: integer;
begin
   // AnsiString deliberately: these are byte protocols, and a UnicodeString
   // would put a zero between every character.  The same trap the radio factory
   // documents for CI-V and Yaesu binary frames.
   a := AnsiString(aText);
   SetLength(Result, Length(a));
   for i := 1 to Length(a) do
      begin
      Result[i - 1] := Byte(a[i]);
      end;
end;

function TRotatorBase.StopFrame: TBytes;
begin
   // No stop command by default.  A driver that has one overrides this AND
   // declares rcStop; the two go together, and Stop below is what enforces it.
   Result := nil;
end;

procedure TRotatorBase.Send(const aBytes: TBytes);
begin
   if (Length(aBytes) > 0) and Assigned(FSend) then
      begin
      FSend(aBytes);
      end;
end;

procedure TRotatorBase.TurnTo(const aAzimuth: integer);
var
   az: integer;
begin
   // NORMALISED ONCE, HERE.  A caller computing a bearing can easily arrive at
   // 360 (due north the long way) or a negative number; every driver formatting
   // that into three digits would produce a frame its rotator rejects, and each
   // would have to remember the same guard.
   az := aAzimuth mod 360;
   if az < 0 then
      begin
      az := az + 360;
      end;

   Send(TurnFrame(az));
end;

function TRotatorBase.PreferredBaudRate: integer;
begin
   // What LogCfg used for every rotator except the DCU-1.
   Result := 9600;
end;

function TRotatorBase.UsesSerialPort: boolean;
begin
   // True for all but PstRotator.  Stated as a default rather than asked of a
   // type, so a future networked rotator answers False by overriding rather
   // than by being added to a list somewhere else.
   Result := True;
end;

procedure TRotatorBase.Stop;
begin
   if not Supports(rcStop) then
      begin
      Exit;
      end;
   Send(StopFrame);
end;

end.

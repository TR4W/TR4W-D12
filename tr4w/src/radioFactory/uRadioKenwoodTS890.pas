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
unit uRadioKenwoodTS890;

{
  Kenwood TS-890S.

  A thin model on TKenwoodLAN (uRadioKenwoodLAN.pas), which holds everything both
  this radio and the TS-990S share: the LAN authentication handshake and the
  Kenwood ASCII CAT implementation. All this unit states is the radio's name and
  the identifier it answers to.

  ID024 is what the radio returns to ID;. The base compares against it so a
  genuine mismatch -- this model selected in the dialog but the other one on the
  wire -- is still reported.

  Previously ONE class served both radios, with an ExpectedIdent property written
  by each registration. NY4I: "One radio per class... when I look at the project I
  should see a class for every single radio." A property that exists only so one
  class can impersonate two models was the tell: a TS-890S owner's log said
  whatever the other model was named.

  Network-only (LAN CAT). Issue #436 -- the radio TR4W's LAN support was written against, and the
  bench-proven one of the pair.
}

interface

uses
  uRadioKenwoodLAN, uFactoryRadioBase, uRadioRegistry, VC;

type
  TKenwoodTS890Radio = class(TKenwoodLAN)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

constructor TKenwoodTS890Radio.Create;
begin
  inherited Create;
  radioModel     := 'Kenwood TS-890S';
  FExpectedIdent := 'ID024';
   // The TS-890 accepts the space-prefixed KY form with a VARIABLE-length P2
   // (KY <space><text>;), so no 24-byte fill -- and never KY2, since P1='2'
   // would key the fill spaces as dead air.  The other Kenwoods reject a short
   // P2 under P1=space, which is why the family base pads and this model does
   // not.  (Was uCWFraming's `TS890:` arm, the one model it named on its own.)
   FCapabilities.CWFrame.pad := False;
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateKenwoodTS890: TFactoryRadioBase;
begin
   Result := TKenwoodTS890Radio.Create;
end;

initialization
  RegisterRadio(TS890,
     CreateKenwoodTS890,
     'Kenwood TS-890S', [rlSerial, rlNetwork], 60000, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     2041
     );

end.

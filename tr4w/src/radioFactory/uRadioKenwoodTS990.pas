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
unit uRadioKenwoodTS990;

{
  Kenwood TS-990S.

  A thin model on TKenwoodLAN (uRadioKenwoodLAN.pas), which holds everything both
  this radio and the TS-890S share: the LAN authentication handshake and the
  Kenwood ASCII CAT implementation. All this unit states is the radio's name and
  the identifier it answers to.

  ID022 is what the radio returns to ID;. The base compares against it so a
  genuine mismatch -- this model selected in the dialog but the other one on the
  wire -- is still reported.

  Previously ONE class served both radios, with an ExpectedIdent property written
  by each registration. NY4I: "One radio per class... when I look at the project I
  should see a class for every single radio." A property that exists only so one
  class can impersonate two models was the tell: a TS-990S owner's log said
  whatever the other model was named.

  Network-only (LAN CAT). NOT bench-tested: it rides the TS-890S implementation, which is proven.
}

interface

uses
  uRadioKenwoodLAN, uFactoryRadioBase, uRadioRegistry, VC;

type
  TKenwoodTS990Radio = class(TKenwoodLAN)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

constructor TKenwoodTS990Radio.Create;
begin
  inherited Create;
  radioModel     := 'Kenwood TS-990S';
  FExpectedIdent := 'ID022';
end;

initialization
  RegisterRadio(TS990,
     function: TFactoryRadioBase begin Result := TKenwoodTS990Radio.Create end,
     'Kenwood TS-990S', [rlSerial, rlNetwork], 50000, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.

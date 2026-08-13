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
unit uRadioKenwoodBase;
{$I ..\tr4w.inc}

{
  What every radio speaking the KENWOOD CAT command set has in common -- which
  is not the same thing as "every radio Kenwood makes".

  Three families descend from here:
    * Kenwood serial  (TS-480/570/590/850/890/950/990/2000 ...)
    * Kenwood LAN     (TS-890/990 over TCP)
    * Flex over CAT   -- a FlexRadio speaking the Kenwood command set on a
                         serial port BY DESIGN, which is what makes the is-a
                         honest rather than convenient.

  Two radios that use the same PROSIGN spellings are deliberately NOT here,
  because they do not speak this command set:
    * TTenTecOrionRadio keys '/<char><CR>', one character at a time;
    * TFlexAPI uses the SmartSDR cwx API call, with #127 for a word space.
  Their Kenwood-looking spellings came from LOGRADIO copying its Kenwood arm,
  not from the protocol.  Each states its own, in its own unit.  Inheriting from
  here to save five lines would make every future Kenwood-base behaviour apply
  silently to a radio that is not a Kenwood.
}

interface

uses
   uFactoryRadioBase, uRadioKYBase;

type
   TKenwoodProtocolRadio = class(TKYRadio)
   protected
      procedure DeclareCWProsigns; override;
   end;

implementation

procedure TKenwoodProtocolRadio.DeclareCWProsigns;
begin
   // Kenwood KY spellings.  Order: half space, SN, AR, SK, BT.
   // The half space is a whole space: a KY string has no half space.
   FCapabilities.CWProsigns := CWProsigns(' ', '%', '_', '>', '[');
end;

end.

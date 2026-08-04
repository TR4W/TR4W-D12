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
unit uRadioKYBase;

{
  THE "KY" CW COMMAND -- the base for every radio that keys CW by sending

      KY <text>;      or      KYW<text>;      for the immediate form

  WHY THIS CLASS EXISTS.  Five drivers had their own copy of this: Elecraft
  serial, the K4, Kenwood serial, Kenwood LAN and Flex-over-CAT.  Four called a
  shared formatter in uCWFraming and the fifth hand-rolled the same string,
  which is how the divergence starts.  Worse, the formatter itself was a
  RADIO-SPECIFIC command sitting in a unit whose whole purpose is generic text
  mechanics -- so a Yaesu gaining CW-by-CAT would have meant editing shared code
  to describe a Yaesu.  Everything a KY radio does about CW now lives on a KY
  radio, and uCWFraming is left with chunking and padding, which have no radio
  in them at all.

  WHAT IS NOT HERE.  The prosign SPELLINGS.  Elecraft and Kenwood both send KY
  and disagree about how to spell AR, SK and BT inside it, so those belong one
  level down -- see uRadioElecraftBase and uRadioKenwoodBase.  Nor is StopCW:
  the abort differs per family ('KY <04>;RX;' on a K3, 'KY0;RX;' on a Kenwood
  LAN) and each driver states its own.

  NOT EVERY CW-BY-CAT RADIO IS A KY RADIO, and this class is deliberately not
  their parent:
    * TIcomRadio sends CI-V $17 with the text following the command byte;
    * TTenTecOrionRadio sends '/<char><CR>', ONE CHARACTER at a time;
    * TFlexAPI sends the SmartSDR cwx API call, with #127 for a word space.
  Those three declare their own prosign spellings in their own units.  Making
  them descend from here to inherit a table would be inheritance for code
  reuse, claiming a protocol relationship that does not exist.
}

interface

uses
   uFactoryRadioBase;

type
   TKYRadio = class(TFactoryRadioBase)
   protected
      // Text accumulated by BufferCW and emitted by SendCW.  Was declared
      // separately in each of the five drivers.
      CWBuffer: string;

      // The command itself.  Virtual so a KY radio with a quirk can state it
      // without reimplementing the buffering around it; no subclass needs to
      // today.
      //
      // `immediate` selects the KYW form, which IS documented (K3 command
      // reference, KY): the SET format is KY*[text] where * is normally a blank,
      // and a 'W' there means WAIT -- processing of any following host commands
      // is delayed until the current message has been sent.  LOGRADIO used it
      // when a speed change (Ctrl-F / Ctrl-S) forced the buffer out mid-message,
      // which is consistent: the KS that follows must not be acted on until the
      // text has gone.  (NY4I supplied the manual page 2026-08-01.)
      function CWCommand(const text: string; immediate: boolean): string; virtual;

   public
      procedure BufferCW(cwChars: string); override;
      procedure SendCW; override;
   end;

implementation

uses
   MainUnit;   // the global `logger`

function TKYRadio.CWCommand(const text: string; immediate: boolean): string;
begin
   if immediate then
      begin
      Result := 'KYW' + text + ';';
      end
   else
      begin
      Result := 'KY ' + text + ';';
      end;
end;

procedure TKYRadio.BufferCW(cwChars: string);
begin
   CWBuffer := CWBuffer + cwChars;
end;

procedure TKYRadio.SendCW;
begin
   if CWBuffer = '' then
      begin
      Exit;
      end;
   logger.Info('[%s.SendCW] Sending CW: "%s"', [radioModel, CWBuffer]);
   Self.SendToRadio(CWCommand(CWBuffer, Self.CWSendImmediate));
   CWBuffer := '';
   Self.CWSendImmediate := False;
end;

end.

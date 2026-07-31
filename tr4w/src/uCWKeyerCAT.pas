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
unit uCWKeyerCAT;

{
  CW-by-CAT adapter -- keys CW by sending text to the RADIO over the CAT link
  (RadioObject.SendCW).  THIN delegation with verbatim semantics from the
  LogCW/MainUnit bodies it replaces; every quirk preserved on purpose (see the
  Q-list in docs/CW_Keyer_Factory_Plan.md):

  - Message keying resolves KeyersSwapped (send on the INACTIVE radio when
    swapped); autosend chars always target the ACTIVE radio, unswapped and
    without UpCase (Q6).
  - Calls RadioObject methods only -- never bypasses into tFactoryObject.  The
    commented kludge in LOGRADIO.SendCW stays until legacy radio removal; this
    adapter is the future single repoint.
  - CAT busy is timer-guessed by the radio object (Q10), not read back.
}

interface

uses
   VC, uCWKeyerBase;

type
   TCWKeyerCAT = class(TCWKeyer)
   public
      constructor Create;
      procedure SendString(const Msg: Str160; Tone: integer); override;
      procedure SendChar(ch: Char); override;
      function StillBeingSent: boolean; override;
      function DeleteLastChar: boolean; override;
      procedure Flush; override;
      procedure StopSending; override;
      // SetSpeed: inherited no-op.  Radio speed-sync is orthogonal to which
      // keyer keys (it must fire even when the WinKeyer keys), so it stays in
      // the LogCW facade, not here.
   end;

implementation

uses
   MainUnit,   // IsCWByCATActive, CWByCATBufferTerminator, DebugMsg
   LogRadio,   // ActiveRadioPtr / InactiveRadioPtr (typed consts), RadioObject
   LogCW;      // KeyersSwapped

constructor TCWKeyerCAT.Create;
begin
   inherited Create;
   FName := 'CW-by-CAT';
   FCapabilities := [ckDeleteLastChar, ckMessageChaining];
end;

procedure TCWKeyerCAT.SendString(const Msg: Str160; Tone: integer);
begin
   // Verbatim from LogCW.AddStringToBuffer's CAT arm; Tone is not a CAT
   // concept and is ignored.
   if KeyersSwapped then
      begin
      InactiveRadioPtr.SendCW(Msg);
      end
   else
      begin
      ActiveRadioPtr.SendCW(Msg);
      end;
end;

procedure TCWKeyerCAT.SendChar(ch: Char);
begin
   // Verbatim from MainUnit.CallWindowKeyDownProc's CAT arm: ACTIVE radio, no
   // swap resolution, no UpCase (Q6), terminator closes the one-char message.
   ActiveRadioPtr.SendCW(ch);
   ActiveRadioPtr.SendCW(CWByCATBufferTerminator);
end;

function TCWKeyerCAT.StillBeingSent: boolean;
begin
   Result := ActiveRadioPtr.CWByCAT_Sending;
end;

function TCWKeyerCAT.DeleteLastChar: boolean;
begin
   Result := ActiveRadioPtr.DeleteLastCWCharacter;
end;

procedure TCWKeyerCAT.Flush;
begin
   // Verbatim from LogCW.FlushCWBuffer's CAT blocks: BOTH radios, each gated
   // by mode = CW and per-radio CW-by-CAT eligibility.
   if ActiveRadioPtr.CurrentStatus.Mode = CW then
      begin
      if IsCWByCATActive(ActiveRadioPtr) then
         begin
         DebugMsg('Flushing CWBuffer - Stop Sending on ActiveRadio CWBC');
         ActiveRadioPtr.CWByCATBuffer := '';
         ActiveRadioPtr.StopSendingCW;
         end;
      end;
   if InactiveRadioPtr.CurrentStatus.Mode = CW then
      begin
      if IsCWByCATActive(InactiveRadioPtr) then
         begin
         DebugMsg('Flushing CWBuffer - Stop Sending on InactiveRadio CWBC');
         InactiveRadioPtr.CWByCATBuffer := '';
         InactiveRadioPtr.StopSendingCW;
         end;
      end;
end;

procedure TCWKeyerCAT.StopSending;
begin
   // Verbatim from MainUnit's Escape handler (inner body; the ActiveMode = CW
   // shell stays at the call site): stop whichever radio is CAT-keying.
   if IsCWByCATActive(ActiveRadioPtr) then
      begin
      ActiveRadioPtr^.StopSendingCW;
      end
   else if IsCWByCATActive(InactiveRadioPtr) then
      begin
      InactiveRadioPtr^.StopSendingCW;
      end;
end;

initialization
   KeyerCAT := TCWKeyerCAT.Create;

finalization
   KeyerCAT.Free;
   KeyerCAT := nil;

end.

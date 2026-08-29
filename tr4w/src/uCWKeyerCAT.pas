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
{$I tr4w.inc}

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
   VC, uCWKeyerBase,
   // RadioPtr.  This is the CAT repoint: the CW-by-CAT send logic lives HERE
   // now, not in RadioObject.SendCW, so this unit's interface has to name the
   // radio type.  Legal because LogRadio takes uCWKeyerCAT in its
   // IMPLEMENTATION -- Delphi only forbids a cycle when both sides are in the
   // interface.
   LogRadio;

// Send one CW-by-CAT token to a specific radio.
//
// This IS RadioObject.SendCW, moved.  It buffers until the terminator arrives
// (or a speed change forces the buffer out), frames the text per the radio's
// rules, arms the busy window and hands each chunk to the driver.  None of that
// is radio-driver work and none of it is contest-logging work -- it is what a
// CAT keyer does, so it belongs to the CAT keyer.
//
// Takes the radio explicitly rather than assuming ActiveRadioPtr: SendString
// resolves the SO2R swap itself, and the interrupt/interlock paths need to act
// on a nominated radio.
procedure CWByCATSend(radio: RadioPtr; const Msg: Str160);

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
      procedure EnsureSoleTransmitter(sendingOnActiveRadio: boolean); override;
      // SetSpeed: inherited no-op.  Radio speed-sync is orthogonal to which
      // keyer keys (it must fire even when the WinKeyer keys), so it stays in
      // the LogCW facade, not here.
   end;

implementation

uses
   Windows,    // Sleep -- the interlock's settle delay
   SysUtils,
   Log4D,
   MainUnit,   // IsCWByCATActive, CWByCATBufferTerminator, DebugMsg, logger
   LogCW,      // KeyersSwapped, CalculateElements
   Tree,       // CodeSpeed -- the operator's current WPM
   LogWind,    // DisplayedCodeSpeed -- what the CW timing estimate is based on
   uRadioRegistry,
   uFactoryRadioBase,   // TCWProsign -- the radio answers, so the type is its
   uCWFraming;

procedure CWByCATSend(radio: RadioPtr; const Msg: Str160);
var
   frameRule: uCWFraming.TCWFrameRule;
   prosign: uFactoryRadioBase.TCWProsign;
   chunkIx: integer;
   chunk: string;
   text: string;
   elements: integer;
   sendNow: boolean;
begin
   // Q9: the RADIO's own capability, not a model-keyed table -- two sources of
   // truth for "can this radio key over CAT" disagreeing shows up as CW that
   // simply never goes out.  Kept here rather than assumed of the caller: this
   // is reachable from SendStringAndStop as well as from the keyer's own
   // methods.
   //
   // HasCapability asks the factory object first.  The model-keyed form that
   // stood here could not see a string-id radio at all (RadioModel =
   // NoInterfacedRadio by design), so TCI reached this gate and exited -- CW
   // was configured, speed sync worked, and not one cw_macros ever went out.
   if not ( radio.CWByCAT and radio.HasCapability(rcCWByCAT) ) then
      begin
      Exit;
      end;

   // No driver means construction was refused or failed, which
   // SetUpRadioInterface has already reported as an ERROR.  There is no legacy
   // path left to fall back to, and doing nothing beats half-keying through
   // code nobody else runs.
   if radio.tFactoryObject = nil then
      begin
      Exit;
      end;

   sendNow := False;

   if Msg = ControlF then          // speed up 6%, and flush what is buffered
      begin
      CodeSpeed := CodeSpeed + Round(CodeSpeed * 0.06);
      sendNow := True;
      end
   else if Msg = ControlS then     // speed down 6%
      begin
      CodeSpeed := CodeSpeed - Round(CodeSpeed * 0.06);
      sendNow := True;
      end
   else if Msg <> CWByCATBufferTerminator then
      begin
      // The RADIO spells its own prosigns.  This was a dialect enum switched on
      // inside uCWFraming, with the three spelling tables there too -- so a new
      // CW-by-CAT family meant editing a shared unit to describe one vendor's
      // radio.  Each family base now declares its spellings as capability data
      // and subclasses inherit them; nothing outside the factory knows a
      // grammar exists.
      prosign := radio.tFactoryObject.CWProsign(Msg);
      if prosign.handled then
         begin
         radio.CWByCATBuffer := radio.CWByCATBuffer + prosign.text;
         end
      else
         begin
         radio.CWByCATBuffer := radio.CWByCATBuffer + Msg;
         end;
      end;

   // Still collecting: nothing goes out until the terminator arrives or a speed
   // change forces the buffer.
   if not ( (Msg = CWByCATBufferTerminator) or sendNow ) then
      begin
      Exit;
      end;

   text := radio.CWByCATBuffer;
   radio.CWByCATBuffer := '';
   if text = '' then
      begin
      Exit;
      end;

   DebugMsg('Assembling CW message to send');
   // The RADIO states how its CW command must be cut up.  This was a lookup by
   // RadioModel plus a `tCATPortType = Network` test -- the transport test being
   // there only because ONE model enum (FLEX) covered two protocols.  TFlexCAT
   // and TFlexAPI are separate classes and each states its own rule, so both the
   // table and the transport test are gone.
   frameRule := radio.tFactoryObject.Capabilities.CWFrame;

   // Only one radio may key at a time.  Note this ALSO issues the keyer abort
   // when the other radio is mid-message, and TElecraftSerial.StopCW carries a
   // settle delay after its RX -- without which a short following message
   // never keys (bench, 2026-08-01).
   KeyerCAT.EnsureSoleTransmitter(radio.active);

   for chunkIx := 1 to uCWFraming.CWChunkCount(text, frameRule) do
      begin
      chunk := uCWFraming.CWChunk(text, frameRule, chunkIx);
      // Count elements on the UNPADDED text: the radio trims trailing pad
      // spaces instead of keying them, so counting them inflates the busy
      // window (a 1-char '?' padded to 22 once gave a bogus ~8 s). Issue 153.
      elements := CalculateElements(
                     uCWFraming.CWChunkUnpadded(text, frameRule, chunkIx));
      logger.trace('Total CW Elements (unpadded) = %d', [elements]);
      // The busy window must cover the WHOLE message, not just the last chunk.
      // EnableCWBYCATTimer always SETS the interval -- its "add to a running
      // timer" branch is commented out with the note that updating a live timer
      // "does not work properly" -- so calling it per chunk would leave a
      // multi-chunk message with a window sized to its final chunk, expiring
      // early and letting the poll thread step on CW still being keyed.
      // AddTimeToCWByCATTimer exists for exactly this: arm on the first chunk,
      // extend on the rest.
      if chunkIx = 1 then
         begin
         radio.EnableCWBYCATTimer(
            Round( (1200 / DisplayedCodeSpeed) * elements * frameRule.busyFactor));
         end
      else
         begin
         radio.AddTimeToCWByCATTimer(
            Round( (1200 / DisplayedCodeSpeed) * elements * frameRule.busyFactor));
         end;
      radio.CWByCAT_Sending := True;
      // Fresh message: we have not seen this one transmit yet.  Until we do, a
      // TX-off or PTT-off poll must not be read as "finished" (CWByCAT_SawTX).
      radio.CWByCAT_SawTX := False;
      logger.trace('Self.CWByCAT_Sending set to TRUE');

      radio.tFactoryObject.SendCWImmediate := sendNow;
      radio.tFactoryObject.BufferCW(chunk);
      radio.tFactoryObject.SendCW;
      end;

   if sendNow then
      begin
      radio.SetRadioCWSpeed(CodeSpeed);
      end;
end;

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
      CWByCATSend(InactiveRadioPtr, Msg);
      end
   else
      begin
      CWByCATSend(ActiveRadioPtr, Msg);
      end;
end;

procedure TCWKeyerCAT.SendChar(ch: Char);
begin
   // Verbatim from MainUnit.CallWindowKeyDownProc's CAT arm: ACTIVE radio, no
   // swap resolution, no UpCase (Q6), terminator closes the one-char message.
   CWByCATSend(ActiveRadioPtr, ch);
   CWByCATSend(ActiveRadioPtr, CWByCATBufferTerminator);
end;

function TCWKeyerCAT.StillBeingSent: boolean;
begin
   Result := ActiveRadioPtr.CWByCAT_Sending;
end;

function TCWKeyerCAT.DeleteLastChar: boolean;
begin
   Result := ActiveRadioPtr.DeleteLastCWCharacter;
end;

procedure TCWKeyerCAT.EnsureSoleTransmitter(sendingOnActiveRadio: boolean);
begin
   // Moved VERBATIM from LOGRADIO.RadioObject.SendCW's chunk loop.  Unlike every
   // other keyer, CW-by-CAT drives two INDEPENDENT transmitters, so both radios
   // really can key at once -- this is what stops that.
   //
   // The log text names the SENDING radio in both messages, including the
   // "Stopping sending CW on ..." line, which reads as though the sender is the
   // one being stopped.  Preserved as-is: operators and old logs depend on the
   // wording, and this move is meant to be behaviour-identical.
   //
   // ASYMMETRY PRESERVED, NOT ENDORSED: the active branch sleeps 500 ms after
   // stopping the other radio; the inactive branch does not sleep at all.  The
   // 2026-07-31 SO2R bench run never reached either branch (TR4W's SO2R swaps
   // which radio is ACTIVE, so sends always take the active path and the other
   // radio's CW is stopped by SWAPRADIOS instead).  This code belongs to the
   // SetUpToSendOnInactiveRadio / dueling-CQ flow and is therefore UNTESTED --
   // N4AF owns validating it.  Do not "tidy" the sleep without a two-radio test.
   if sendingOnActiveRadio then
      begin
      DebugMsg('Sending on ACTIVE radio ' + ActiveRadioPtr.RadioName + ' (' +
               RadioTypeToken(ActiveRadioPtr.RadioModel) + ')');
      if InactiveRadioPtr.CWByCAT_Sending then
         begin
         DebugMsg('Stopping sending CW on INACTIVE ' + ActiveRadioPtr.RadioName +
                  ' (' + RadioTypeToken(ActiveRadioPtr.RadioModel) + ')');
         InactiveRadioPtr.StopSendingCW;
         Sleep(500); // Give command chance to complete
         end;
      end
   else
      begin
      DebugMsg('Sending on INACTIVE radio ' + InactiveRadioPtr.RadioName + ' (' +
               RadioTypeToken(InactiveRadioPtr.RadioModel) + ')');
      if ActiveRadioPtr.CWByCAT_Sending then
         begin
         DebugMsg('Stopping sending CW on ACTIVE ' + InactiveRadioPtr.RadioName +
                  ' (' + RadioTypeToken(InactiveRadioPtr.RadioModel) + ')');
         ActiveRadioPtr.StopSendingCW;
         end;
      end;
end;

procedure TCWKeyerCAT.Flush;
begin
   // Verbatim from LogCW.FlushCWBuffer's CAT blocks: BOTH radios, each gated
   // by mode = CW and per-radio CW-by-CAT eligibility.
   // The CWByCAT_Sending test is NEW and load-bearing.  Without it this fired a
   // keyer abort before EVERY function-key message, including when the radio was
   // sitting idle -- and then the message went out 3 ms behind it.  On a K3 the
   // abort/RX transition swallows what follows that closely, so the message
   // simply never keyed.  Bench, NY4I 2026-08-01: F1 keyed with a 10 ms gap
   // between abort and message; F4 did not, with a 3 ms gap.  Both were
   // identically formed and padded to 22 on the wire.
   //
   // Intermittent by nature, which is why it read as "sometimes no CW": whether
   // the radio swallows the message depends on how tightly the two land.
   //
   // Same defect class as the WinKeyer flush fixed the day before -- doing
   // device I/O on behalf of a keyer that is not sending.  The buffer is still
   // cleared unconditionally; only the ABORT is conditional, because an abort
   // is only meaningful against CW that is actually going out.
   if ActiveRadioPtr.CurrentStatus.Mode = CW then
      begin
      if IsCWByCATActive(ActiveRadioPtr) then
         begin
         ActiveRadioPtr.CWByCATBuffer := '';
         if ActiveRadioPtr.CWByCAT_Sending then
            begin
            DebugMsg('Flushing CWBuffer - Stop Sending on ActiveRadio CWBC');
            ActiveRadioPtr.StopSendingCW;
            end;
         end;
      end;
   if InactiveRadioPtr.CurrentStatus.Mode = CW then
      begin
      if IsCWByCATActive(InactiveRadioPtr) then
         begin
         InactiveRadioPtr.CWByCATBuffer := '';
         if InactiveRadioPtr.CWByCAT_Sending then
            begin
            DebugMsg('Flushing CWBuffer - Stop Sending on InactiveRadio CWBC');
            InactiveRadioPtr.StopSendingCW;
            end;
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

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
unit uCWKeyerBase;

{ CW Keyer factory -- send path only (this pass).

  TR4W has four mutually-exclusive ways to key CW: CW-by-CAT (radio SendCW over
  the CAT link), a WinKeyer device (uWinKey), the YCCC SO2R+ box (uYCCCSO2R),
  and the CPU keyer toggling DTR/RTS/LPT (K1EAKeyer in LOGK1EA, driven from
  LogCW).  LogCW.pas is the de-facto facade, but each facade procedure
  re-implements the same 4-way dispatch and the copies have drifted.  This unit
  gives the dispatch ONE home: a TCWKeyer strategy class, four singleton
  adapters (uCWKeyerCAT/WinKey/YCCC/CPU), and one selection function.  Mirrors
  the strangler pattern proven on the radio factory (uFactoryRadioBase /
  uRadioRegistry): the adapters are THIN -- all state stays in today's globals
  -- until the seam is proven on hardware, after which the implementations
  migrate into the keyer classes.  Full plan: docs/CW_Keyer_Factory_Plan.md.

  PTT (MainUnit PTTOn/PTTOff) and SO2R output switching
  (SetUpToSendOn*Radio / wkSetKeyerOutput / SetRelayForActiveRadio /
  YCCCSetActiveRadio) are OUT of scope; when they migrate they become
  virtuals here (e.g. PTTOn/PTTOff, SetKeyerOutput(radio)). }

interface

uses
   VC;   // Str160

type
   TCWKeyerCapability = (
      ckTune,             // key-down tune (WinKeyer KEYIMMEDIATE only today)
      ckDeleteLastChar,   // can retract the last unsent buffered character
      ckMessageChaining   // messages buffered until a terminator closes them
      );
   TCWKeyerCapabilitySet = set of TCWKeyerCapability;

   // Virtual with DEFAULT BODIES, not abstract: several operations are
   // legitimately optional per keyer (ToggleTune, StopSending, SetSpeed
   // no-ops), and default bodies avoid the known trap where /t:Make hides
   // W1020 missing-abstract warnings.
   TCWKeyer = class(TObject)
   protected
      FName: string;
      FCapabilities: TCWKeyerCapabilitySet;
   public
      procedure SendString(const Msg: Str160; Tone: integer); virtual;
      procedure SendChar(ch: Char); virtual;            // autosend, one char now
      function StillBeingSent: boolean; virtual;        // default False
      function DeleteLastChar: boolean; virtual;        // default False
      procedure Flush; virtual;                         // this keyer's arm of FlushCWBuffer
      procedure StopSending; virtual;                   // Escape stop; default no-op
      procedure SetSpeed(wpm: integer); virtual;
      procedure ToggleTune; virtual;                    // default no-op
      function Supports(cap: TCWKeyerCapability): boolean;
      property Name: string read FName;
      property Capabilities: TCWKeyerCapabilitySet read FCapabilities;
   end;

var
   // Singleton slots, installed by each adapter unit's initialization section.
   // Listed EXPLICITLY in both tr4w.dpr and the test dpr -- a unit reached only
   // transitively vanishes when the chain changes (the uRadioIcomLegacy lesson).
   KeyerCAT: TCWKeyer = nil;
   KeyerWinKey: TCWKeyer = nil;
   KeyerYCCC: TCWKeyer = nil;
   KeyerCPU: TCWKeyer = nil;

// The active keyer, re-evaluated PER CALL (no cached selection, no hooks):
//   CW-by-CAT -> WinKeyer -> YCCC -> CPU
// This pins today's AddStringToBuffer precedence and resolves the two hard
// correctness points by construction:
// - WinKeyer async open: wkActive only goes True inside the read thread after
//   a successful echo test; a WinKeyer that never opens falls through to
//   YCCC/CPU exactly as today.
// - Per-radio CW-by-CAT: IsCWByCATActive follows ActiveRadioPtr (config AND
//   rcCWByCAT capability), so radio swaps and model changes need no
//   re-selection events.
function ActiveCWKeyer: TCWKeyer;

// Once, after config load (LogCfg): a single Warn per conflicting keyer
// configuration, so the log explains surprising keying instead of the operator
// discovering precedence by experiment.
procedure WarnIfKeyerConfigsConflict;

implementation

uses
   SysUtils, Log4D, MainUnit, uWinKey, uYCCCSO2R, LogRadio, uRadioRegistry;

var
   // Log-on-change memory for ActiveCWKeyer.  Read/written from more than one
   // thread without a lock: worst case is a duplicated or skipped LOG LINE,
   // never a wrong selection (benign race, deliberate).
   LastLoggedKeyer: TCWKeyer = nil;

procedure TCWKeyer.SendString(const Msg: Str160; Tone: integer);
begin
   // Default: no-op.
end;

procedure TCWKeyer.SendChar(ch: Char);
begin
   // Default: no-op.
end;

function TCWKeyer.StillBeingSent: boolean;
begin
   Result := False;
end;

function TCWKeyer.DeleteLastChar: boolean;
begin
   Result := False;
end;

procedure TCWKeyer.Flush;
begin
   // Default: no-op.
end;

procedure TCWKeyer.StopSending;
begin
   // Default: no-op.
end;

procedure TCWKeyer.SetSpeed(wpm: integer);
begin
   // Default: no-op.
end;

procedure TCWKeyer.ToggleTune;
begin
   // Default: no-op.
end;

function TCWKeyer.Supports(cap: TCWKeyerCapability): boolean;
begin
   Result := cap in FCapabilities;
end;

function ActiveCWKeyer: TCWKeyer;
begin
   if IsCWByCATActive then
      begin
      Result := KeyerCAT;
      end
   else if wkActive then
      begin
      Result := KeyerWinKey;
      end
   else if ycccActive then
      begin
      Result := KeyerYCCC;
      end
   else
      begin
      Result := KeyerCPU;
      end;
   if (Result <> LastLoggedKeyer) and (Result <> nil) then
      begin
      LastLoggedKeyer := Result;
      logger.Info('Active CW keyer is now %s', [Result.Name]);
      end;
end;

procedure WarnIfKeyerConfigsConflict;
var
   catConfigured: boolean;
begin
   if WinKeySettings.wksWinKey2Enable and YCCCSo2rEnable then
      begin
      logger.Warn('CW keyer config conflict: WINKEYER ENABLE and YCCC SO2R ENABLE are both set. '
                + 'The WinKeyer wins when it opens; the YCCC box will not key CW.');
      end;
   catConfigured :=
      (Radio1.CWByCAT and uRadioRegistry.SupportsFor(Radio1.RadioModel, rcCWByCAT)) or
      (Radio2.CWByCAT and uRadioRegistry.SupportsFor(Radio2.RadioModel, rcCWByCAT));
   if catConfigured and
      (WinKeySettings.wksWinKey2Enable or YCCCSo2rEnable) then
      begin
      logger.Warn('CW keyer config conflict: CW BY CAT is enabled on a capable radio together with '
                + 'a WinKeyer/YCCC keyer. CW-by-CAT wins while that radio is active; the hardware '
                + 'keyer only keys when it is not.');
      end;
end;

end.

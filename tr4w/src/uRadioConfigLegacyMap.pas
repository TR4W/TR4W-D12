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
unit uRadioConfigLegacyMap;

{
  Renders a radio definition as the legacy [Radio] ini keys -- and NOTHING else.

  WHY IT IS ITS OWN UNIT.  Putting a definition on the air means writing the
  keys CFGCA understands and then telling CFGCA to re-read them.  The second
  half needs uCFG, LOGRADIO, LogCW and the whole global world; the first half is
  a pure function from a record to a list of (key, value) pairs.  Splitting them
  means the part that is easy to get subtly wrong -- 26 key spellings, three of
  which do not follow the pattern -- is the part that can be unit-tested.

  It is also where a whole class of bug is prevented.  If activating a
  definition writes only SOME of the keys, the rest are left over from the radio
  that was configured BEFORE, and the operator gets an IC-7100 running with a
  K3's CI-V address or a stale keyer port.  So the renderer emits the COMPLETE
  set every time, including the keys whose value is empty; there is a test that
  compares the emitted key set against a golden list lifted from CFGCA.

  ON THE THREE KEYS THAT BREAK THE PATTERN.  Most keys read 'RADIO ONE <thing>'.
  Three do not, and every one of them is a place a plausible-looking guess would
  produce a key CFGCA silently ignores:

      KEYER RADIO ONE OUTPUT PORT     (not RADIO ONE KEYER OUTPUT PORT)
      POLL RADIO ONE                  (not RADIO ONE POLL)
      RADIO ONE FACTORY ID            follows the pattern, but see below

  ON TYPE vs FACTORY ID.  A radio driven by the factory is identified by a
  STRING id and writes TYPE=NONE plus FACTORY ID=<id>; a legacy enum radio
  writes TYPE=<enum name> and must have any stale FACTORY ID key DELETED, or
  the factory picks the old radio up again.  Which of the two a given
  registry id is, is a question for uRadioRegistry -- which this unit
  deliberately does not use.  The caller resolves it and passes the answer in
  as TRadioTypeRendering, which is what keeps this unit pure and testable.

  ON DELETION.  A rendered entry can mean "delete this key" rather than "write
  this value" (Value is ignored then).  That is not the same as writing an empty
  string: WritePrivateProfileString with a nil value REMOVES the key, and for
  FACTORY ID removal is the only thing that works.
}

interface

uses
   System.SysUtils,
   uRadioConfigStore;

type
   // One instruction for the caller: write Value under Key, or delete Key.
   TConfigKeyValue = record
      Key: string;
      Value: string;
      // True = remove the key entirely (a nil value to
      // WritePrivateProfileStringA).  Value is not meaningful.
      Delete: boolean;
   end;

   TConfigKeyValues = array of TConfigKeyValue;

   { What the caller resolved about this radio's identity and defaults by
     consulting the registry.  Passed IN so that this unit needs no registry of
     its own.

     The DEFAULTS matter more than they look.  A numeric config key written as
     an empty value does NOT mean "use the default" to CFGCA -- it means "this
     was never set", so the variable KEEPS WHATEVER IT ALREADY HELD, which is
     the previously activated radio's value (uCFG.pas:1243-1253, and it raises a
     notice per key while doing it).  So every numeric key has to carry a real
     number, and when the operator has not chosen one that number is the model's
     own default, which only the registry knows. }
   TRadioTypeRendering = record
      // True for a factory (string-id) radio: TYPE=NONE + FACTORY ID=<id>.
      IsFactoryRadio: boolean;
      // For an enum radio, the InterfacedRadioTypeSA spelling ('IC7300',
      // 'K3', ...).  Ignored when IsFactoryRadio.
      LegacyTypeName: string;
      // Model defaults, used wherever the operator left a field blank.
      DefaultCIVAddress: integer;
      DefaultBaudRate: integer;
      DefaultTCPPort: integer;
      DefaultHamLibID: integer;
   end;

// The complete key set for one slot, in a fixed order.  aProfile may be nil,
// in which case the radio's own CWByCAT/CWSpeedSync are used rather than the
// profile's per-slot CW output.
// aNamesAKeyerDevice says the profile's CW output resolved to a DEVICE in the
// keyer library.  A boolean rather than the device's port, because such a
// device owns and opens its own port: what this unit needs to know is only
// that the legacy CPU-keying key must stay NONE.  The lookup is the caller's,
// so this unit stays free of the keyer library, exactly as it is free of the
// registry.
function RenderRadioKeys(const aSlot: integer;
                         const aRadio: TRadioDefinition;
                         const aTypeRendering: TRadioTypeRendering;
                         const aProfile: TStationProfile;
                         const aNamesAKeyerDevice: boolean = False): TConfigKeyValues;

// The same key set, rendered for "there is no radio in this slot".  Used when
// a profile fills only slot one: without it, slot two keeps whatever the
// previously active profile left there.
function RenderEmptySlot(const aSlot: integer): TConfigKeyValues;

// The key names this unit emits, in the same order, without needing a radio.
// Exists so a test can compare the set against CFGCA, and so the apply layer
// can log what it is about to touch.
function RenderedKeyNames(const aSlot: integer): TArray<string>;

// 'ONE' or 'TWO'.  Public because the apply layer logs with it.
function SlotWord(const aSlot: integer): string;

implementation

const
   TRUEVALUE  = 'TRUE';
   FALSEVALUE = 'FALSE';

   // The tr4w_RTSDTRType vocabulary is NONE / OFF / ON / CW / PTT
   // (LOGRADIO.PAS:92).  Empty is not a member of it: CFGCA rejects
   // 'RADIO ONE CAT RTS=' as "Invalid statement in config file", which aborts
   // the whole config load -- it does not merely skip the line.  That is a
   // harder failure than the empty-numeric one, and it is what stopped the
   // headless corpus export dead (2026-08-05).
   RTSDTR_NONE = 'NONE';

function SlotWord(const aSlot: integer): string;
begin
   if aSlot = 2 then
      begin
      Result := 'TWO';
      end
   else
      begin
      Result := 'ONE';
      end;
end;

function BoolValue(const aValue: boolean): string;
begin
   // CFGCA's boolean vocabulary, not Delphi's -- 'True' would not parse.
   if aValue then
      begin
      Result := TRUEVALUE;
      end
   else
      begin
      Result := FALSEVALUE;
      end;
end;

{ The key table.  ONE place, used by both the renderer and RenderedKeyNames, so
  the two can never disagree about what the complete set is.

  Each entry is a suffix appended to 'RADIO <slot> ', EXCEPT the two marked
  below, which have their own shape.  Order is the order they are written; it
  does not matter to the ini, but a stable order makes the apply log readable
  and the pin test deterministic. }
type
   TKeyShape = (ksRadioPrefixed,    // 'RADIO ONE ' + suffix
                ksKeyerOutputPort,  // 'KEYER RADIO ONE OUTPUT PORT'
                ksPollRadio);       // 'POLL RADIO ONE'

   TKeySpec = record
      Shape: TKeyShape;
      Suffix: string;
   end;

const
   KEYSPECS: array[0..26] of TKeySpec = (
      // identity
      (Shape: ksRadioPrefixed;   Suffix: 'TYPE'),
      (Shape: ksRadioPrefixed;   Suffix: 'FACTORY ID'),
      (Shape: ksRadioPrefixed;   Suffix: 'NAME'),
      // serial transport
      (Shape: ksRadioPrefixed;   Suffix: 'CONTROL PORT'),
      (Shape: ksRadioPrefixed;   Suffix: 'BAUD RATE'),
      (Shape: ksRadioPrefixed;   Suffix: 'SERIAL FORMAT'),
      (Shape: ksRadioPrefixed;   Suffix: 'CAT RTS'),
      (Shape: ksRadioPrefixed;   Suffix: 'CAT DTR'),
      // network transport
      (Shape: ksRadioPrefixed;   Suffix: 'IP ADDRESS'),
      (Shape: ksRadioPrefixed;   Suffix: 'TCP PORT'),
      (Shape: ksRadioPrefixed;   Suffix: 'NETWORK USERNAME'),
      (Shape: ksRadioPrefixed;   Suffix: 'NETWORK PASSWORD'),
      // keyer lines
      (Shape: ksKeyerOutputPort; Suffix: ''),
      (Shape: ksRadioPrefixed;   Suffix: 'KEYER RTS'),
      (Shape: ksRadioPrefixed;   Suffix: 'KEYER DTR'),
      (Shape: ksRadioPrefixed;   Suffix: 'KEYER STOP BITS'),
      // CW
      (Shape: ksRadioPrefixed;   Suffix: 'CW BY CAT'),
      (Shape: ksRadioPrefixed;   Suffix: 'CW SPEED SYNC'),
      // model particulars
      (Shape: ksRadioPrefixed;   Suffix: 'USE HAMLIB'),
      (Shape: ksRadioPrefixed;   Suffix: 'HAMLIB ID'),
      (Shape: ksRadioPrefixed;   Suffix: 'RECEIVER ADDRESS'),
      (Shape: ksRadioPrefixed;   Suffix: 'ICOM DATA MODE ID'),
      (Shape: ksRadioPrefixed;   Suffix: 'ICOM FILTER BYTE'),
      (Shape: ksRadioPrefixed;   Suffix: 'AUTO INFO'),
      (Shape: ksRadioPrefixed;   Suffix: 'WIDE CW FILTER'),
      (Shape: ksRadioPrefixed;   Suffix: 'FT1000MP CW REVERSE'),
      (Shape: ksRadioPrefixed;   Suffix: 'FREQUENCY ADDER')
   );

   // RenderRadioKeys emits its keys EXPLICITLY rather than walking this table,
   // because each one needs a different value expression and a table of those
   // would be less readable than the code, not more.  The risk that buys is
   // drift: an emitted key that is not in the table, or vice versa.  That is
   // what the pin test checks -- emitted set == RenderedKeyNames == the golden
   // list lifted from CFGCA -- so drift fails a test rather than shipping.

function KeyName(const aSlot: integer; const aSpec: TKeySpec): string;
begin
   case aSpec.Shape of
      ksKeyerOutputPort:
         begin
         // NOT 'RADIO ONE KEYER OUTPUT PORT' -- CFGCA spells it this way round
         // and would silently ignore the other.
         Result := 'KEYER RADIO ' + SlotWord(aSlot) + ' OUTPUT PORT';
         end;
      ksPollRadio:
         begin
         Result := 'POLL RADIO ' + SlotWord(aSlot);
         end;
   else
      begin
      Result := 'RADIO ' + SlotWord(aSlot) + ' ' + aSpec.Suffix;
      end;
   end;
end;

// The two keys outside KEYSPECS, so that "the complete set" is one list in one
// place rather than a table plus some ad-hoc additions.
const
   EXTRAKEYSPECS: array[0..2] of TKeySpec = (
      (Shape: ksRadioPrefixed;   Suffix: 'BAND OUTPUT PORT'),
      (Shape: ksRadioPrefixed;   Suffix: 'STARTUP COMMAND'),
      (Shape: ksPollRadio;       Suffix: '')
   );

function RenderedKeyNames(const aSlot: integer): TArray<string>;
var
   i, n: integer;
begin
   n := Length(KEYSPECS) + Length(EXTRAKEYSPECS);
   SetLength(Result, n);
   for i := 0 to High(KEYSPECS) do
      begin
      Result[i] := KeyName(aSlot, KEYSPECS[i]);
      end;
   for i := 0 to High(EXTRAKEYSPECS) do
      begin
      Result[Length(KEYSPECS) + i] := KeyName(aSlot, EXTRAKEYSPECS[i]);
      end;
end;

// Appends one instruction.  Local helper so the renderer below reads as a list
// of decisions rather than as array bookkeeping.
procedure Emit(var aList: TConfigKeyValues; const aKey, aValue: string;
               const aDelete: boolean = False);
var
   n: integer;
begin
   n := Length(aList);
   SetLength(aList, n + 1);
   aList[n].Key    := aKey;
   aList[n].Value  := aValue;
   aList[n].Delete := aDelete;
end;

// A list-valued key that must never be blank -- see RTSDTR_NONE.
function ListValue(const aValue, aDefault: string): string;
begin
   if Trim(aValue) <> '' then
      begin
      Result := Trim(aValue);
      end
   else
      begin
      Result := aDefault;
      end;
end;

// A numeric field, resolved to a CONCRETE value.
//
// It must never render empty.  CFGCA reads an empty numeric as "never set" and
// leaves the variable alone -- so an empty here would silently keep the
// PREVIOUS radio's baud rate or CI-V address, which is precisely the leak this
// renderer exists to prevent.  It also raises a notice per key, which is how
// the defect was found: activating a profile produced a queue of "has no value
// in the config file" dialogs (NY4I 2026-08-05).
//
// aValue = 0 means the operator did not choose one, so the model default is
// written instead.  When there is no model default either, 0 is written --
// which is a legitimate value for every key that reaches that case
// (FREQUENCY ADDER, ICOM FILTER BYTE, KEYER STOP BITS).
// BAUD RATE is a ckArray command: CFGCA accepts only a MEMBER of
// CAT_BAUDRATE_ARRAY (1200..115200), so unlike every other numeric here a 0 is
// REJECTED -- "Invalid statement in config file" at the next startup, on a line
// this renderer wrote (NY4I, 2026-08-08: RADIO TWO BAUD RATE=0 from a cleared
// slot).  The slot has no radio, so the value is inert; it only has to parse.
const
   LOWEST_LEGAL_BAUD = '1200';   // CAT_BAUDRATE_ARRAY[0], spelled here to keep
                                 // this renderer free of uCFG -- pinned by test.

function BaudRateValue(const aValue, aDefault: integer): string;
begin
   if aValue <> 0 then
      begin
      Result := IntToStr(aValue);
      end
   else if aDefault <> 0 then
      begin
      Result := IntToStr(aDefault);
      end
   else
      begin
      Result := LOWEST_LEGAL_BAUD;
      end;
end;

function NumericValue(const aValue, aDefault: integer): string;
begin
   if aValue <> 0 then
      begin
      Result := IntToStr(aValue);
      end
   else
      begin
      Result := IntToStr(aDefault);
      end;
end;

// Is this the PortTypeSA vocabulary rather than something else?  'NONE',
// 'SERIAL n', 'LPT n' -- anything else would be rejected by CheckCommand.
const
   // The profile's radio-relative CW token, spelled as uKeyerConfigStore
   // declares it (CWOUT_RADIOPORT).  Repeated rather than imported to keep this
   // renderer dependency-free -- the same reason CWOUTPUT_CAT is not imported
   // from the UI.  One vocabulary, two declarations, and a test that would fail
   // if they diverged.
   CWOUT_RADIOPORT = 'RADIOPORT';

function LooksLikePortValue(const aValue: string): boolean;
var
   v: string;
begin
   v := UpperCase(Trim(aValue));
   Result := (v = '') or (v = PORT_NONE) or
             (Copy(v, 1, 7) = 'SERIAL ') or (Copy(v, 1, 4) = 'LPT ');
end;

function RenderRadioKeys(const aSlot: integer;
                         const aRadio: TRadioDefinition;
                         const aTypeRendering: TRadioTypeRendering;
                         const aProfile: TStationProfile;
                         const aNamesAKeyerDevice: boolean = False): TConfigKeyValues;
var
   slot: string;
   cwOutput: string;
   cwByCAT: boolean;
   keyerPort: string;
   speedSync: boolean;
begin
   Result := nil;
   if aRadio = nil then
      begin
      Result := RenderEmptySlot(aSlot);
      Exit;
      end;

   slot := SlotWord(aSlot);

   // --- identity ----------------------------------------------------------
   // A factory radio is TYPE=NONE plus FACTORY ID; an enum radio is the
   // reverse AND must have the stale FACTORY ID key deleted, or the factory
   // resurrects the previous radio.  This mirrors uCAT's own save path.
   if aTypeRendering.IsFactoryRadio then
      begin
      Emit(Result, 'RADIO ' + slot + ' TYPE', 'NONE');
      Emit(Result, 'RADIO ' + slot + ' FACTORY ID', aRadio.RegistryId);
      end
   else
      begin
      Emit(Result, 'RADIO ' + slot + ' TYPE', aTypeRendering.LegacyTypeName);
      Emit(Result, 'RADIO ' + slot + ' FACTORY ID', '', True);
      end;

   Emit(Result, 'RADIO ' + slot + ' NAME', aRadio.Name);

   // --- transport ----------------------------------------------------------
   // Both transports' keys are written every time, with the inapplicable ones
   // blanked.  A network radio that leaves a stale CONTROL PORT behind would
   // have TR4W open a serial port it must not touch -- which on a shared port
   // means stealing it from the OTHER radio.
   if aRadio.Transport = rtNetwork then
      begin
      // TCP/IP, NOT blank.  CONTROL PORT is the key that SELECTS the link, not
      // a serial-only setting to be cleared alongside BAUD RATE: 'SERIAL n' is
      // the serial link, 'TCP/IP' is the network one, and NONE means the radio
      // has no link at all.  Writing NONE here to avoid opening a COM port also
      // withdrew "use the network", so a K4 with a good IP ADDRESS and TCP PORT
      // came up as `connection=NO PORT SET` and the factory refused to build a
      // driver for it -- `NO FACTORY DRIVER built for Elecraft K4 on port 0`.
      // Found on the bench by NY4I, 2026-08-05.
      Emit(Result, 'RADIO ' + slot + ' CONTROL PORT',  PORT_NETWORK);
      Emit(Result, 'RADIO ' + slot + ' BAUD RATE',
           BaudRateValue(aRadio.BaudRate, aTypeRendering.DefaultBaudRate));
      Emit(Result, 'RADIO ' + slot + ' SERIAL FORMAT', '');
      Emit(Result, 'RADIO ' + slot + ' CAT RTS',       RTSDTR_NONE);
      Emit(Result, 'RADIO ' + slot + ' CAT DTR',       RTSDTR_NONE);

      Emit(Result, 'RADIO ' + slot + ' IP ADDRESS',       aRadio.IPAddress);
      Emit(Result, 'RADIO ' + slot + ' TCP PORT',
           NumericValue(aRadio.TCPPort, aTypeRendering.DefaultTCPPort));
      Emit(Result, 'RADIO ' + slot + ' NETWORK USERNAME', aRadio.NetworkUsername);
      Emit(Result, 'RADIO ' + slot + ' NETWORK PASSWORD', aRadio.NetworkPassword);
      end
   else
      begin
      Emit(Result, 'RADIO ' + slot + ' CONTROL PORT',  aRadio.ControlPort);
      Emit(Result, 'RADIO ' + slot + ' BAUD RATE',
           BaudRateValue(aRadio.BaudRate, aTypeRendering.DefaultBaudRate));
      Emit(Result, 'RADIO ' + slot + ' SERIAL FORMAT', aRadio.SerialFormat);
      Emit(Result, 'RADIO ' + slot + ' CAT RTS',       ListValue(aRadio.CatRTS, RTSDTR_NONE));
      Emit(Result, 'RADIO ' + slot + ' CAT DTR',       ListValue(aRadio.CatDTR, RTSDTR_NONE));

      // Blanked, not left alone: see above.
      Emit(Result, 'RADIO ' + slot + ' IP ADDRESS',       '');
      Emit(Result, 'RADIO ' + slot + ' TCP PORT',
           NumericValue(aRadio.TCPPort, aTypeRendering.DefaultTCPPort));
      Emit(Result, 'RADIO ' + slot + ' NETWORK USERNAME', '');
      Emit(Result, 'RADIO ' + slot + ' NETWORK PASSWORD', '');
      end;

   // --- CW output ----------------------------------------------------------
   // The PROFILE decides how CW reaches this slot, because that is a property
   // of the station wiring rather than of the radio: the same K3 keys by CAT
   // at home and off a WinKeyer portable.  With no profile the radio's own
   // fields stand in, which is what seeding produces.
   cwByCAT   := aRadio.CWByCAT;
   keyerPort := aRadio.KeyerOutputPort;
   speedSync := aRadio.CWSpeedSync;

   if aProfile <> nil then
      begin
      if aSlot = 2 then
         begin
         cwOutput  := Trim(aProfile.CWOutput2);
         speedSync := aProfile.SpeedSync2;
         end
      else
         begin
         cwOutput  := Trim(aProfile.CWOutput1);
         speedSync := aProfile.SpeedSync1;
         end;

      if SameText(cwOutput, CWOUTPUT_CAT) then
         begin
         cwByCAT   := True;
         keyerPort := PORT_NONE;
         end
      else if (cwOutput = '') or SameText(cwOutput, CWOUTPUT_NONE) then
         begin
         cwByCAT   := False;
         keyerPort := PORT_NONE;
         end
      else if SameText(cwOutput, CWOUT_RADIOPORT) then
         begin
         // Keying on the radio's OWN control port: the port is the radio's, not
         // a device's.
         cwByCAT   := False;
         keyerPort := aRadio.KeyerOutputPort;
         end
      else if aNamesAKeyerDevice then
         begin
         // The profile names a DEVICE -- a WinKeyer or a YCCC box -- and such a
         // device OWNS ITS PORT and opens it itself.  This key must therefore
         // stay NONE.  Putting the device's port here instead told LOGK1EA to
         // ALSO key DTR/RTS on that port; it opened COM20 exclusively first and
         // the WinKeyer thread then died with "Access is denied" (NY4I,
         // 2026-08-08).  Two keying mechanisms cannot share one port.
         cwByCAT   := False;
         keyerPort := PORT_NONE;
         end
      else
         begin
         // A profile written BEFORE the keyer library holds a raw port value
         // here, so it is passed through -- that is the migration path.
         //
         // It is also the last resort, and it must not emit a DEVICE NAME: the
         // legacy key takes the PortTypeSA vocabulary, and CheckCommand rejects
         // anything else with "Invalid statement in config file" at startup.
         // That is exactly what a keyer named 'WinKeyer' produced (NY4I,
         // 2026-08-08) once the profile started holding device names.
         cwByCAT := False;
         if LooksLikePortValue(cwOutput) then
            begin
            keyerPort := cwOutput;
            end
         else
            begin
            keyerPort := PORT_NONE;
            end;
         end;
      end;

   Emit(Result, 'KEYER RADIO ' + slot + ' OUTPUT PORT', keyerPort);
   Emit(Result, 'RADIO ' + slot + ' KEYER RTS',       ListValue(aRadio.KeyerRTS, RTSDTR_NONE));
   Emit(Result, 'RADIO ' + slot + ' KEYER DTR',       ListValue(aRadio.KeyerDTR, RTSDTR_NONE));
   Emit(Result, 'RADIO ' + slot + ' KEYER STOP BITS', NumericValue(aRadio.KeyerStopBits, 0));

   Emit(Result, 'RADIO ' + slot + ' CW BY CAT',     BoolValue(cwByCAT));
   Emit(Result, 'RADIO ' + slot + ' CW SPEED SYNC', BoolValue(speedSync));

   // --- model particulars ---------------------------------------------------
   Emit(Result, 'RADIO ' + slot + ' USE HAMLIB', BoolValue(aRadio.UseHamLib));
   // HAMLIB ID is the operator's number only for the HamLib-any selection; for
   // every other radio the legacy dialog shows a greyed informational value
   // that must not be written back.  Same rule here, one layer up.
   if SameText(aRadio.RegistryId, 'HAMLIBANY') then
      begin
      Emit(Result, 'RADIO ' + slot + ' HAMLIB ID',
           NumericValue(aRadio.HamLibID, aTypeRendering.DefaultHamLibID));
      end
   else
      begin
      // The registry's id for the chosen model.  Not blank: a blank numeric
      // would leave the PREVIOUS radio's HamLib id in place, which is exactly
      // the wrong rig to drive through HamLib.
      Emit(Result, 'RADIO ' + slot + ' HAMLIB ID',
           NumericValue(aTypeRendering.DefaultHamLibID, 0));
      end;

   Emit(Result, 'RADIO ' + slot + ' RECEIVER ADDRESS',
        NumericValue(aRadio.ReceiverAddress, aTypeRendering.DefaultCIVAddress));
   // CFGCA's range for this one is 1..3, so 0 is not a legal fallback.
   Emit(Result, 'RADIO ' + slot + ' ICOM DATA MODE ID',
        NumericValue(aRadio.IcomDataModeID, 1));
   Emit(Result, 'RADIO ' + slot + ' ICOM FILTER BYTE',    NumericValue(aRadio.IcomFilterByte, 0));
   Emit(Result, 'RADIO ' + slot + ' AUTO INFO',           NumericValue(aRadio.AutoInfoLevel, 0));
   Emit(Result, 'RADIO ' + slot + ' WIDE CW FILTER',      BoolValue(aRadio.WideCWFilter));
   Emit(Result, 'RADIO ' + slot + ' FT1000MP CW REVERSE', BoolValue(aRadio.FT1000MPCWReverse));
   Emit(Result, 'RADIO ' + slot + ' FREQUENCY ADDER',     NumericValue(aRadio.FrequencyAdder, 0));
   Emit(Result, 'RADIO ' + slot + ' BAND OUTPUT PORT',    aRadio.BandOutputPort);
   Emit(Result, 'RADIO ' + slot + ' STARTUP COMMAND',     aRadio.StartupCommand);

   Emit(Result, 'POLL RADIO ' + slot, BoolValue(aRadio.PollingEnable));
end;

function RenderEmptySlot(const aSlot: integer): TConfigKeyValues;
var
   names: TArray<string>;
   i: integer;
   slot: string;
begin
   Result := nil;
   slot := SlotWord(aSlot);
   names := RenderedKeyNames(aSlot);

   for i := 0 to High(names) do
      begin
      if names[i] = 'RADIO ' + slot + ' TYPE' then
         begin
         // TYPE=NONE is how the legacy configuration says "no radio here"; an
         // empty value would not parse as a radio type.
         Emit(Result, names[i], 'NONE');
         end
      else if names[i] = 'RADIO ' + slot + ' FACTORY ID' then
         begin
         // Deleted rather than blanked -- a blank FACTORY ID is still a key,
         // and the factory would try to resolve it.
         Emit(Result, names[i], '', True);
         end
      else if names[i] = 'RADIO ' + slot + ' CONTROL PORT' then
         begin
         Emit(Result, names[i], PORT_NONE);
         end
      else if names[i] = 'KEYER RADIO ' + slot + ' OUTPUT PORT' then
         begin
         Emit(Result, names[i], PORT_NONE);
         end
      else if names[i] = 'RADIO ' + slot + ' BAND OUTPUT PORT' then
         begin
         Emit(Result, names[i], PORT_NONE);
         end
      else if (names[i] = 'POLL RADIO ' + slot)              or
              (names[i] = 'RADIO ' + slot + ' CW BY CAT')    or
              (names[i] = 'RADIO ' + slot + ' CW SPEED SYNC') or
              (names[i] = 'RADIO ' + slot + ' USE HAMLIB')   or
              (names[i] = 'RADIO ' + slot + ' WIDE CW FILTER') or
              (names[i] = 'RADIO ' + slot + ' FT1000MP CW REVERSE') then
         begin
         // The booleans go to FALSE rather than empty: CFGCA reads an empty
         // boolean as unchanged, which would leave the previous radio's
         // setting in force on a slot that is supposed to be off.
         Emit(Result, names[i], FALSEVALUE);
         end
      else if (names[i] = 'RADIO ' + slot + ' CAT RTS')   or
              (names[i] = 'RADIO ' + slot + ' CAT DTR')   or
              (names[i] = 'RADIO ' + slot + ' KEYER RTS') or
              (names[i] = 'RADIO ' + slot + ' KEYER DTR') then
         begin
         // List-valued: blank is not in the vocabulary and is REJECTED, not
         // ignored.
         Emit(Result, names[i], RTSDTR_NONE);
         end
      else if (names[i] = 'RADIO ' + slot + ' ICOM DATA MODE ID') then
         begin
         // 1..3 in CFGCA -- an empty or zero value is not legal.
         Emit(Result, names[i], '1');
         end
      else if (names[i] = 'RADIO ' + slot + ' BAUD RATE') then
         begin
         // NOT 0 -- see BaudRateValue.  Every other numeric below takes 0
         // happily; this one is the exception because it is ckArray.
         Emit(Result, names[i], LOWEST_LEGAL_BAUD);
         end
      else if (names[i] = 'RADIO ' + slot + ' TCP PORT')          or
              (names[i] = 'RADIO ' + slot + ' KEYER STOP BITS')   or
              (names[i] = 'RADIO ' + slot + ' HAMLIB ID')         or
              (names[i] = 'RADIO ' + slot + ' RECEIVER ADDRESS')  or
              (names[i] = 'RADIO ' + slot + ' ICOM FILTER BYTE')  or
              (names[i] = 'RADIO ' + slot + ' AUTO INFO')         or
              (names[i] = 'RADIO ' + slot + ' FREQUENCY ADDER')   then
         begin
         // Numerics get an explicit 0, never blank.  Blank means "never set"
         // to CFGCA, which would leave the departing radio's value in force on
         // a slot that is meant to be empty.
         Emit(Result, names[i], '0');
         end
      else
         begin
         Emit(Result, names[i], '');
         end;
      end;
end;

end.

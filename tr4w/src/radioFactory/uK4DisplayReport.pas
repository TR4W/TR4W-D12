(*
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
*)
unit uK4DisplayReport;
{$I ..\tr4w.inc}

(*
  DECODING THE K4'S OWN DISPLAY SETTINGS, AS THE RADIO REPORTS THEM.

  WHY THIS UNIT EXISTS.  The K4 publishes its panadapter settings on the CAT
  port as '#' commands -- reference level, scale, AutoRef, waterfall height,
  waterfall colour range, averaging, frame rate -- and pushes them when the
  operator turns a knob on the front panel.  TR4W's panadapter follows the LCD
  waterfall ones -- height, colour range, colour scheme -- through
  K4LiveDisplay (docs/PANADAPTER_LCL_DESIGN.md section 10.5).  Nothing here
  sends or draws.

  WHAT THIS UNIT IS.  A PURE function over a string, on the pattern of
  uElecraftIF: no logger, no radio object, no I/O, no LCL.  TK4Radio calls it
  from its reading thread under its own lock (uRadioElecraftK4); the tests call
  it with the radio's own strings (uTestK4DisplayReport).

  THE WIRE FORMATS.  TR4W receives each message WITHOUT its ';' (ReadLn
  consumes it); one trailing ';' is tolerated anyway.  Sources: QK4 commit
  485a7c15 -- resources/k4_cat_commands.json, src/models/radiostate/
  spectrumdisplaystate.cpp/.h (ranges from the K4 Programmer's Reference D12)
  and docs/k4-protocol-quirks.md section 13 (AutoRef, measured on a K4D on
  2026-10-19).  Leading zeros on received values are NOT KNOWN either way --
  the reference writes '#WFHnnn' and '#AVGnn', the radio has been seen to send
  '#SCL080' -- so both '#AVG2' and '#AVG02' are accepted.

    #REF<v>     main receiver reference level, dB, signed, -200..60
    #REF$<v>    the same for the SUB receiver ('$' = sub, as everywhere on K4)
    #SCL<v>     display scale (window height), dB, 10..150.  ONE value for
                main and sub: the K4 has no #SCL$.
    #WFH<v>     waterfall share of the LCD panadapter, percent, 0..100
    #HWFH<v>    the same for the external monitor
    #WBS<v>     waterfall colour range ("WTR CLRS"), LCD, 5..30
    #HWBS<v>    the same for the external monitor
    #WFC<v>     waterfall colour scheme, LCD, 0..4: 0 gray, 1 color, 2 teal
                tone, 3 blue tone, 4 sepia tone.  The manual writes the LCD
                form '#WFC$', but the radio answers and pushes plain '#WFC'
                (NY4I, measured on a K4, 2026-11-03: '#WFC$;' returns '#WFC'),
                so '#WFC' is what is parsed and asked.
    #AVG<v>     spectrum averaging, frames, 1..20
    #FPS<v>     panadapter frame rate, 1..30
    #ARaadd+oom AutoRef, exactly eight characters after '#AR':
                  aa  averaging constant, two digits, 01..20
                  dd  debounce constant, two digits -- RANGE UNKNOWN: QK4's
                      command table says 4..9, but the radio has been seen to
                      send 01 ('#AR1201+041') and 06 ('#AR1206+041'), so it is
                      read and kept but never range-checked
                  +   sign of the offset, '+' or '-'
                  oo  AutoRef offset, dB, two digits, -8..+8 with the sign
                  m   1 = AutoRef on, 0 = off (NOT 'A'/'M' -- that was an
                      invented format, see quirks section 13)

  WHAT IS DELIBERATELY NOT DECODED, and returns False:
    #SPN / #SPN$  already handled by TK4Radio itself -- do not move it here in
                  passing;
    #HREF / #HREF$  the external monitor's reference.  It is pushed beside
                  #REF while AutoRef tracks, and must not be mistaken for it;
    #HWFC         the external monitor's colour scheme.  TR4W's window follows
                  the LCD (NY4I, 2026-11-03), so it is not kept at all -- and
                  it cannot be read as '#WFC', whose second character differs;
    everything else.

  WHAT THE WINDOW FOLLOWS.  K4LiveDisplay translates a receiver's record into
  the neutral TSpectrumLiveDisplay the panadapter reads: #WFH, #WBS and #WFC
  -- the LCD values -- and that receiver's #REF (#REF$ for the sub) and the
  shared #SCL.  The external monitor's #HWFH and #HWBS are kept on
  TK4DisplayState as facts and reach no window.

  HELD, NOT RESET, ACROSS A RECONNECT (NY4I, 2026-11-03).  There is no reset:
  a value stands until the radio reports a new one, so a K4 that drops its
  link keeps its picture.  A different radio is a different TK4Radio, which
  starts from K4DisplayStateUnknown.

  SCOPE.  #REF belongs to the main receiver and #REF$ to the sub; the global
  reports (#SCL, #WFH, #WBS, #WFC, #AVG, #AR) are stored in BOTH receiver records,
  because the radio states one value that governs both.  The external-monitor
  values and the frame rate are K4 facts with no neutral home, and live on
  TK4DisplayState beside the two receivers.

  REJECTION.  A malformed or out-of-range value changes NOTHING -- no flag, no
  value, no Generation -- and the function returns False.  "The radio sent
  junk" must never read as "the radio said zero".
*)

interface

uses
   uSpectrumTypes;   // TSpectrumRadioState.  This unit is a leaf: nothing in
                     // the factory may ever use uK4DisplayReport in return
                     // except the K4 driver.

const
   K4_REF_MIN_DB = -200;
   K4_REF_MAX_DB = 60;
   K4_SCALE_MIN_DB = 10;
   K4_SCALE_MAX_DB = 150;
   K4_WATERFALL_MIN_PERCENT = 0;
   K4_WATERFALL_MAX_PERCENT = 100;
   K4_COLOUR_RANGE_MIN = 5;
   K4_COLOUR_RANGE_MAX = 30;
   K4_COLOUR_MODE_MIN = 0;
   K4_COLOUR_MODE_MAX = 4;
   K4_AVG_MIN_FRAMES = 1;
   K4_AVG_MAX_FRAMES = 20;
   K4_FPS_MIN = 1;
   K4_FPS_MAX = 30;
   K4_AUTOREF_AVG_MIN = 1;
   K4_AUTOREF_AVG_MAX = 20;
   K4_AUTOREF_OFFSET_MIN_DB = -8;
   K4_AUTOREF_OFFSET_MAX_DB = 8;

   (* What TK4Radio asks at every network link-up, beside '#SPN;'.  READS
      ONLY: each is the command with no value, which is the K4's GET form
      (QK4 resources/k4_cat_commands.json, getFormat).  It must never carry a
      value -- a client #REF freezes AutoRef, and '#AR0;' resets it.  Pinned
      by uTestRadioSocketNoRead. *)
   K4_DISPLAY_QUERIES = '#REF;#SCL;#AR;#WFH;#WBS;#WFC;#AVG;';

   (* THE WATERFALL COLOUR FLOOR, AS A FRACTION OF THE SCALE PER #WBS STEP.
      The palette's bottom sits SCALE x #WBS / K4_COLOUR_FLOOR_DIVISOR dB below
      the reference and spans SCALE dB from there.  This is QK4's mapping
      (src/dsp/waterfallgeometry, colorWindowFor, at 485a7c15) and QK4 says
      plainly what it is: a PHOTOGRAPHIC FIT to one K4D (2026-10-30, WWV,
      AutoRef, #WBS 14, SCALE 25/50/80), with the #WBS term UNVERIFIED --
      every photo was at 14.  The K4 manual says only that a higher WTR CLRS
      "will use brighter colors", which a lower floor gives.  Correct it here
      and nowhere else.  At #WBS 5 and an 80 dB scale it gives exactly 10 dB,
      the margin the window has always used. *)
   K4_COLOUR_FLOOR_DIVISOR = 40.0;

type
   (* Everything the K4 has reported about its display, per receiver plus the
      K4-only values.  No managed fields: TK4Radio returns parts of it by value
      from under a lock. *)
   TK4DisplayState = record
      Main: TSpectrumRadioState;           // pan A
      Sub: TSpectrumRadioState;            // pan B
      HasFps: Boolean;
      Fps: Integer;                        // #FPS
      HasExtWaterfall: Boolean;
      ExtWaterfallPercent: Integer;        // #HWFH
      HasExtColourRange: Boolean;
      ExtColourRange: Integer;             // #HWBS
      HasAutoRefTiming: Boolean;
      AutoRefAveraging: Integer;           // #AR aa
      AutoRefDebounce: Integer;            // #AR dd -- range unknown, see above
      Generation: Integer;                 // EVERY accepted report, any kind
   end;

(* Nothing known, every Generation 0. *)
function K4DisplayStateUnknown: TK4DisplayState;

(* Decode one message into AState.  True when it was one of the reports above
   and its value was legal; AState is then updated and the Generation of every
   record it touched moved on, even when the value equals the one held.
   False otherwise, and AState is untouched. *)
function ParseK4DisplayReport(const AMsg: string; var AState: TK4DisplayState): Boolean;

(* WHAT THE WINDOW SHOULD FOLLOW, from one receiver's record: #WFH as a share,
   #WBS as a colour floor (K4_COLOUR_FLOOR_DIVISOR), #WFC as a palette tone,
   the receiver's #REF as the reference and #SCL as the scale.
   A value the record does not know -- or one outside the radio's range, which
   the parser never stores -- is not claimed, so the window keeps its
   defaults for it.  Pure. *)
function K4LiveDisplay(const AState: TSpectrumRadioState): TSpectrumLiveDisplay;

implementation

const
   (* Leading zeros are accepted, so allow more digits than any legal value
      needs; the range check is what bounds the value.  Four digits cannot
      overflow an Integer. *)
   MAX_VALUE_DIGITS = 4;

function K4DisplayStateUnknown: TK4DisplayState;
begin
   Result := Default(TK4DisplayState);
end;

function IsDigit(c: Char): Boolean;
begin
   Result := (c >= '0') and (c <= '9');
end;

(* A decimal number filling AText from AFrom to the end: an optional sign when
   AAllowSign, then 1..MAX_VALUE_DIGITS digits and nothing else.  Written out
   rather than StrToIntDef/Val, which accept a '$' hex prefix and leading
   blanks -- '#REF$' would otherwise be one character from being read as hex. *)
function ParseWholeNumber(const AText: string; AFrom: Integer;
                          AAllowSign: Boolean; out AValue: Integer): Boolean;
var
   i: Integer;
   sign: Integer;
   digits: Integer;
begin
   Result := False;
   AValue := 0;
   sign := 1;
   i := AFrom;

   if i > Length(AText) then
      begin
      Exit;
      end;

   if AAllowSign and ((AText[i] = '-') or (AText[i] = '+')) then
      begin
      if AText[i] = '-' then
         begin
         sign := -1;
         end;
      Inc(i);
      end;

   digits := Length(AText) - i + 1;

   if (digits < 1) or (digits > MAX_VALUE_DIGITS) then
      begin
      Exit;
      end;

   while i <= Length(AText) do
      begin
      if not IsDigit(AText[i]) then
         begin
         AValue := 0;
         Exit;
         end;
      AValue := (AValue * 10) + (Ord(AText[i]) - Ord('0'));
      Inc(i);
      end;

   AValue := AValue * sign;
   Result := True;
end;

(* The value after APrefix, in AMin..AMax.  False when AMsg does not start with
   APrefix or the value is not a legal one. *)
function PrefixedValue(const AMsg, APrefix: string; AAllowSign: Boolean;
                       AMin, AMax: Integer; out AValue: Integer): Boolean;
begin
   Result := False;
   AValue := 0;

   if Copy(AMsg, 1, Length(APrefix)) <> APrefix then
      begin
      Exit;
      end;

   if not ParseWholeNumber(AMsg, Length(APrefix) + 1, AAllowSign, AValue) then
      begin
      Exit;
      end;

   Result := (AValue >= AMin) and (AValue <= AMax);
end;

function StartsWith(const AMsg, APrefix: string): Boolean;
begin
   Result := Copy(AMsg, 1, Length(APrefix)) = APrefix;
end;

(* #ARaadd+oom -- see the unit header.  AMsg has had any ';' removed. *)
function ParseAutoRef(const AMsg: string; out AAveraging, ADebounce,
                      AOffsetDb: Integer; out AOn: Boolean): Boolean;
const
   AR_LENGTH = 11;    // '#AR' + 8
var
   i: Integer;
begin
   Result := False;
   AAveraging := 0;
   ADebounce := 0;
   AOffsetDb := 0;
   AOn := False;

   if Length(AMsg) <> AR_LENGTH then
      begin
      Exit;
      end;

   (* Pascal strings are 1-based: '#AR' is 1..3, aa 4..5, dd 6..7, the sign 8,
      oo 9..10 and m 11. *)
   for i := 4 to 7 do
      begin
      if not IsDigit(AMsg[i]) then
         begin
         Exit;
         end;
      end;

   if not (IsDigit(AMsg[9]) and IsDigit(AMsg[10])) then
      begin
      Exit;
      end;

   if (AMsg[8] <> '+') and (AMsg[8] <> '-') then
      begin
      Exit;
      end;

   if (AMsg[11] <> '0') and (AMsg[11] <> '1') then
      begin
      Exit;
      end;

   AAveraging := ((Ord(AMsg[4]) - Ord('0')) * 10) + (Ord(AMsg[5]) - Ord('0'));
   ADebounce := ((Ord(AMsg[6]) - Ord('0')) * 10) + (Ord(AMsg[7]) - Ord('0'));
   AOffsetDb := ((Ord(AMsg[9]) - Ord('0')) * 10) + (Ord(AMsg[10]) - Ord('0'));

   if AMsg[8] = '-' then
      begin
      AOffsetDb := -AOffsetDb;
      end;

   AOn := AMsg[11] = '1';

   (* The debounce is deliberately NOT range-checked -- see the header. *)
   Result := (AAveraging >= K4_AUTOREF_AVG_MIN)        and
             (AAveraging <= K4_AUTOREF_AVG_MAX)        and
             (AOffsetDb >= K4_AUTOREF_OFFSET_MIN_DB)   and
             (AOffsetDb <= K4_AUTOREF_OFFSET_MAX_DB);
end;

procedure Touch(var AState: TSpectrumRadioState);
begin
   AState.Generation := NextSpectrumRadioStateGeneration(AState.Generation);
end;

function ParseK4DisplayReport(const AMsg: string; var AState: TK4DisplayState): Boolean;
var
   msg: string;
   value: Integer;
   averaging, debounce, offsetDb: Integer;
   autoOn: Boolean;
begin
   Result := False;
   msg := AMsg;

   if (Length(msg) > 0) and (msg[Length(msg)] = ';') then
      begin
      SetLength(msg, Length(msg) - 1);
      end;

   if (Length(msg) < 2) or (msg[1] <> '#') then
      begin
      Exit;
      end;

   (* '#REF$' BEFORE '#REF': the main form's prefix is also the sub form's.
      A '#REF$' with a bad value must not then be retried as '#REF' -- '$' is
      not a sign or a digit, so it could not be, but say so. *)
   if StartsWith(msg, '#REF$') then
      begin
      if PrefixedValue(msg, '#REF$', True, K4_REF_MIN_DB, K4_REF_MAX_DB, value) then
         begin
         AState.Sub.HasRef := True;
         AState.Sub.RefDb := value;
         Touch(AState.Sub);
         Result := True;
         end;
      end
   else if StartsWith(msg, '#REF') then
      begin
      if PrefixedValue(msg, '#REF', True, K4_REF_MIN_DB, K4_REF_MAX_DB, value) then
         begin
         AState.Main.HasRef := True;
         AState.Main.RefDb := value;
         Touch(AState.Main);
         Result := True;
         end;
      end
   else if PrefixedValue(msg, '#SCL', False, K4_SCALE_MIN_DB, K4_SCALE_MAX_DB, value) then
      begin
      AState.Main.HasScale := True;
      AState.Main.ScaleDb := value;
      AState.Sub.HasScale := True;
      AState.Sub.ScaleDb := value;
      Touch(AState.Main);
      Touch(AState.Sub);
      Result := True;
      end
   else if PrefixedValue(msg, '#WFH', False, K4_WATERFALL_MIN_PERCENT,
                         K4_WATERFALL_MAX_PERCENT, value) then
      begin
      AState.Main.HasWaterfallFraction := True;
      AState.Main.WaterfallPercent := value;
      AState.Sub.HasWaterfallFraction := True;
      AState.Sub.WaterfallPercent := value;
      Touch(AState.Main);
      Touch(AState.Sub);
      Result := True;
      end
   else if PrefixedValue(msg, '#HWFH', False, K4_WATERFALL_MIN_PERCENT,
                         K4_WATERFALL_MAX_PERCENT, value) then
      begin
      AState.HasExtWaterfall := True;
      AState.ExtWaterfallPercent := value;
      Result := True;
      end
   else if PrefixedValue(msg, '#WBS', False, K4_COLOUR_RANGE_MIN,
                         K4_COLOUR_RANGE_MAX, value) then
      begin
      AState.Main.HasColourRange := True;
      AState.Main.ColourRange := value;
      AState.Sub.HasColourRange := True;
      AState.Sub.ColourRange := value;
      Touch(AState.Main);
      Touch(AState.Sub);
      Result := True;
      end
   else if PrefixedValue(msg, '#HWBS', False, K4_COLOUR_RANGE_MIN,
                         K4_COLOUR_RANGE_MAX, value) then
      begin
      AState.HasExtColourRange := True;
      AState.ExtColourRange := value;
      Result := True;
      end
   else if PrefixedValue(msg, '#WFC', False, K4_COLOUR_MODE_MIN,
                         K4_COLOUR_MODE_MAX, value) then
      begin
      AState.Main.HasColourMode := True;
      AState.Main.ColourMode := value;
      AState.Sub.HasColourMode := True;
      AState.Sub.ColourMode := value;
      Touch(AState.Main);
      Touch(AState.Sub);
      Result := True;
      end
   else if PrefixedValue(msg, '#AVG', False, K4_AVG_MIN_FRAMES, K4_AVG_MAX_FRAMES, value) then
      begin
      AState.Main.HasAvg := True;
      AState.Main.AvgFrames := value;
      AState.Sub.HasAvg := True;
      AState.Sub.AvgFrames := value;
      Touch(AState.Main);
      Touch(AState.Sub);
      Result := True;
      end
   else if PrefixedValue(msg, '#FPS', False, K4_FPS_MIN, K4_FPS_MAX, value) then
      begin
      AState.HasFps := True;
      AState.Fps := value;
      Result := True;
      end
   else if StartsWith(msg, '#AR') and
           ParseAutoRef(msg, averaging, debounce, offsetDb, autoOn) then
      begin
      AState.Main.HasAutoRef := True;
      AState.Main.AutoRef := autoOn;
      AState.Main.AutoRefOffsetDb := offsetDb;
      AState.Sub.HasAutoRef := True;
      AState.Sub.AutoRef := autoOn;
      AState.Sub.AutoRefOffsetDb := offsetDb;
      AState.HasAutoRefTiming := True;
      AState.AutoRefAveraging := averaging;
      AState.AutoRefDebounce := debounce;
      Touch(AState.Main);
      Touch(AState.Sub);
      Result := True;
      end;

   if Result then
      begin
      AState.Generation := NextSpectrumRadioStateGeneration(AState.Generation);
      end;
end;

function K4LiveDisplay(const AState: TSpectrumRadioState): TSpectrumLiveDisplay;
begin
   Result := SpectrumLiveDisplayUnknown;

   if AState.HasWaterfallFraction                                and
      (AState.WaterfallPercent >= K4_WATERFALL_MIN_PERCENT)      and
      (AState.WaterfallPercent <= K4_WATERFALL_MAX_PERCENT) then
      begin
      Result.HasWaterfallShare := True;
      Result.WaterfallShare := AState.WaterfallPercent / 100.0;
      end;

   if AState.HasColourRange                           and
      (AState.ColourRange >= K4_COLOUR_RANGE_MIN)     and
      (AState.ColourRange <= K4_COLOUR_RANGE_MAX) then
      begin
      Result.HasColourFloor := True;
      Result.ColourFloorOfScale := AState.ColourRange / K4_COLOUR_FLOOR_DIVISOR;
      end;

   (* The K4's frames carry real dB (int16 / 10) and the packet's own noise
      floor read within 0.5 dB of #REF under AutoRef (docs/PANADAPTER_LCL_
      DESIGN.md 10.2), so #REF is on the frame's scale and passes as it is. *)
   if AState.HasRef                         and
      (AState.RefDb >= K4_REF_MIN_DB)       and
      (AState.RefDb <= K4_REF_MAX_DB) then
      begin
      Result.HasRef := True;
      Result.RefDb := AState.RefDb;
      end;

   if AState.HasScale                          and
      (AState.ScaleDb >= K4_SCALE_MIN_DB)      and
      (AState.ScaleDb <= K4_SCALE_MAX_DB) then
      begin
      Result.HasScale := True;
      Result.ScaleDb := AState.ScaleDb;
      end;

   (* Spelled out rather than cast: the K4's numbering is the K4's, and the
      neutral enum is free to be reordered without silently re-mapping it. *)
   if AState.HasColourMode then
      begin
      Result.HasPalette := True;

      case AState.ColourMode of
         0:
            begin
            Result.Palette := sptGray;
            end;
         1:
            begin
            Result.Palette := sptColour;
            end;
         2:
            begin
            Result.Palette := sptTeal;
            end;
         3:
            begin
            Result.Palette := sptBlue;
            end;
         4:
            begin
            Result.Palette := sptSepia;
            end;
         else
            begin
            Result.HasPalette := False;
            end;
      end;
      end;
end;

end.

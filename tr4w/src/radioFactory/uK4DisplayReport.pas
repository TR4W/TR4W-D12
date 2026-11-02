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
  operator turns a knob on the front panel.  TR4W will later follow them
  (docs/PANADAPTER_LCL_DESIGN.md section 10).  This is stage 1 of that work:
  the decode, and nothing else.  Nothing here sends, draws or decides.

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
    everything else.

  SCOPE.  #REF belongs to the main receiver and #REF$ to the sub; the global
  reports (#SCL, #WFH, #WBS, #AVG, #AR) are stored in BOTH receiver records,
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
   K4_DISPLAY_QUERIES = '#REF;#SCL;#AR;#WFH;#WBS;#AVG;';

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

(* A new link: every flag cleared, every Generation moved on (never back to 0),
   so a reader that applied the old session's values sees that they are gone. *)
procedure ResetK4DisplayState(var AState: TK4DisplayState);

(* Decode one message into AState.  True when it was one of the reports above
   and its value was legal; AState is then updated and the Generation of every
   record it touched moved on, even when the value equals the one held.
   False otherwise, and AState is untouched. *)
function ParseK4DisplayReport(const AMsg: string; var AState: TK4DisplayState): Boolean;

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

procedure ResetRadioState(var AState: TSpectrumRadioState);
var
   generation: Integer;
begin
   generation := NextSpectrumRadioStateGeneration(AState.Generation);
   AState := SpectrumRadioStateUnknown;
   AState.Generation := generation;
end;

procedure ResetK4DisplayState(var AState: TK4DisplayState);
var
   generation: Integer;
begin
   ResetRadioState(AState.Main);
   ResetRadioState(AState.Sub);

   generation := NextSpectrumRadioStateGeneration(AState.Generation);
   AState.HasFps := False;
   AState.Fps := 0;
   AState.HasExtWaterfall := False;
   AState.ExtWaterfallPercent := 0;
   AState.HasExtColourRange := False;
   AState.ExtColourRange := 0;
   AState.HasAutoRefTiming := False;
   AState.AutoRefAveraging := 0;
   AState.AutoRefDebounce := 0;
   AState.Generation := generation;
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

end.

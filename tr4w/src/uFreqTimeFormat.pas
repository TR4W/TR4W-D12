unit uFreqTimeFormat;
{$I tr4w.inc}

{ Issue #997 / migration Tier-1 extraction.

  Pure frequency & time formatters lifted out of TF.pas so they can be
  golden-master tested (uTestFreqTimeFormat) before and after inline-asm removal.
  TF.pas forwards its FreqToPChar / FreqToPCharWithoutHZ / kHzToPChar /
  MillisecondsToFormattedString / SystemTimeToString to these, so existing call
  sites are unchanged.

  The inline x86 asm (manual cdecl varargs push into wsprintf, plus embedded
  idiv) has been replaced with SysUtils.Format; uTestFreqTimeFormat proves the
  output is byte-identical to the original asm path.

  C->Delphi format-spec mapping used here:
    %02u -> %.2u   (zero-pad width 2  ==  min-2-digit precision, for 0..99)
    %6u  -> %6u    (space-pad width 6, unchanged)
    %.2hu/%.3hu -> %.2u/%.3u  (drop the C 'h' short modifier)

  This unit keeps its OWN scratch buffers (TF still has its copies, used by
  RITFreqToPchar / FreqToPChar2). Dependency-light: Windows + SysUtils. }

interface

uses Windows;

{ D12 modernization: these return native `string` (UTF-16).  They produce pure
  ASCII numeric/time text for the display layer.  The prior PAnsiChar returns
  pointed into shared static buffers -- two calls to any of FreqToPChar /
  FreqToPCharWithoutHZ / kHzToPChar in one expression aliased the SAME buffer.
  A managed `string` result removes that hazard entirely.  Callers that feed a
  Win32 A-API convert explicitly at that boundary (W-API preferred).
  Empty-input signal: FreqToPChar/FreqToPCharWithoutHZ return '' (was nil). }
function FreqToPChar(i: integer): string;
function FreqToPCharWithoutHZ(i: integer): string;
function kHzToPChar(Freq: Word): string;
function MillisecondsToFormattedString(msecs: Cardinal; WithMsec: boolean): string;
function SystemTimeToString(SysTime: SYSTEMTIME): string;
function FormatFullTime(Hour, Minute, Second, Milliseconds: Word; WithMilliseconds: boolean): string;

implementation

uses SysUtils;

function FreqToPChar(i: integer): string;
var
  hz                                    : integer;
begin
  if i = 0 then
  begin
    Result := '';
    Exit;
  end;
  hz := (i mod 1000) div 10;
  // Issue #997: asm wsprintf-push -> SysUtils.Format. khz = i div 1000.
  Result := SysUtils.Format('%u.%.2u', [i div 1000, hz]);
end;

function FreqToPCharWithoutHZ(i: integer): string;
begin
  if i = 0 then
  begin
    Result := '';
    Exit;
  end;

  // Issue #997: asm wsprintf-push -> SysUtils.Format. khz = i div 1000.
  Result := SysUtils.Format('%6u', [i div 1000]);
end;

function kHzToPChar(Freq: Word): string;
begin
  // Issue #997: asm wsprintf-push -> SysUtils.Format.
  Result := SysUtils.Format('%6u', [Freq]);
end;

function MillisecondsToFormattedString(msecs: Cardinal; WithMsec: boolean): string;
var
  Value                                 : Cardinal;
  minuts                                : Word;
  Seconds                               : Word;
  milliseconds                          : Word;
begin
  Value := msecs;

  milliseconds := Value mod 1000;
  Value := Value div 1000;

  Seconds := Value mod 60;
  Value := Value div 60;

  minuts := Value mod 60;
  Value := Value div 60;
  // Issue #997: asm wsprintf-push -> SysUtils.Format. Order HH:MM:SS[:mmm].
  // (Value = hours; a Cardinal msecs caps hours at ~1193, so it always fits the
  // 16-bit truncation the old asm did.)
  if WithMsec then
    Result := SysUtils.Format('%.2u:%.2u:%.2u:%.3u', [Value, minuts, Seconds, milliseconds])
  else
    Result := SysUtils.Format('%.2u:%.2u:%.2u', [Value, minuts, Seconds]);
end;

function SystemTimeToString(SysTime: SYSTEMTIME): string;
begin
  // Issue #997: asm wsprintf-push -> SysUtils.Format. YYYY-MM-DD HH:MM:SS.
  Result := SysUtils.Format('%.2u-%.2u-%.2u %.2u:%.2u:%.2u',
    [SysTime.wYear, SysTime.wMonth, SysTime.wDay,
     SysTime.wHour, SysTime.wMinute, SysTime.wSecond]);
end;

function FormatFullTime(Hour, Minute, Second, Milliseconds: Word; WithMilliseconds: boolean): string;
{ Pure formatting extracted VERBATIM (asm intact) from tree.GetFullTimeString so
  it can be golden-master tested before/after asm removal. tree forwards the UTC
  fields. Local copies (h/m/s/ms) keep the asm operands in memory (the original
  read the UTC global), avoiding register-param clobber. }
begin
  // Issue #997: asm wsprintf-push -> SysUtils.Format (proven byte-identical to
  // the asm baseline by uTestFreqTimeFormat). %.2hu/%.3hu -> %.2u/%.3u.
  if WithMilliseconds then
    Result := SysUtils.Format('%.2u:%.2u:%.2u:%.3u', [Hour, Minute, Second, Milliseconds])
  else
    Result := SysUtils.Format('%.2u:%.2u:%.2u', [Hour, Minute, Second]);
end;

end.

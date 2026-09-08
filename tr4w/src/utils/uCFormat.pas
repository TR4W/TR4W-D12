unit uCFormat;
{$I ..\tr4w.inc}

(* THE RTL'S Format, BEHIND TR4W'S C-STYLE ONE.

  TF.Format was twenty overloads, every one of them

      external user32 Name 'wsprintfA'

  -- a direct binding to Win32's sprintf, called from 555 sites. It is why TF
  needed the Windows unit, and TF is reached by 171 units, so it was the single
  largest thing keeping this tree Windows-bound (measured by the native-Linux
  census, tools/compile-native.sh --every).

  NY4I: "the TF function that the rtl can do should be using the rtl."

  THE SIGNATURES DO NOT CHANGE, so no call site moved. Only the implementation
  did: SysUtils.Format, into the caller's buffer.

  ------------------------------------------------------------------------
  THE CALLERS WERE MADE RTL-COMPATIBLE RATHER THAN TRANSLATED
  ------------------------------------------------------------------------
  The first version of this unit carried a TranslateCFormat that rewrote C's
  dialect into FPC's at run time. NY4I: "You can translate it but the right
  course is to make the callers compatible with the rtl format strings."

  He is right, and the reason is that a translator is a permanent shim nobody
  can see from a call site. The format strings say what they mean now, and
  Lint-CFormat fails the build if a C-only spelling comes back.

  C's printf and FPC's Format agree on everything this tree uses -- %s %d %u
  %x %f, widths, left-justify, %% -- with ONE exception, MEASURED rather than
  read from a manual:

      %02d  with 5    C -> "05"     FPC -> " 5"      the 0 is a WIDTH digit
      %.2d  with 5    C -> "05"     FPC -> "05"      precision zero-pads

  So `%0<n>` became `%.<n>` at the call sites. Note that this was ALREADY
  WRONG at the sites that had moved to SysUtils.Format on their own -- ADIF
  and Cabrillo exchange fields were emitting " 12" where "012" was meant.

  THE 1024-BYTE CAP IS NOT NEW. wsprintfA is documented as writing at most
  1,024 bytes, so callers have always been bounded by that number; it is
  applied here the same way. The signature cannot carry a buffer length --
  that is inherited from the API being replaced, and this unit does not
  pretend to make the write safe, only no worse. *)

interface

const
   { What wsprintfA documents as its maximum, including the terminator. }
   CFORMAT_MAX_BYTES = 1024;

{ Formats into a NUL-terminated buffer and returns the number of characters
  written -- what wsprintfA returned. }
function CFormatBuf(aOutput: PAnsiChar; const aCFormat: AnsiString;
                    const aArgs: array of const): integer;

implementation

uses
   SysUtils;

function CFormatBuf(aOutput: PAnsiChar; const aCFormat: AnsiString;
                    const aArgs: array of const): integer;
var
   s: AnsiString;
begin
   Result := 0;
   if aOutput = nil then
      begin
      Exit;
      end;

   (* A format string the RTL cannot parse was undefined behaviour in
     wsprintfA; here it raises EConvertError, which in a logging or display
     path would take down whatever called it. Caught, and the raw format is
     emitted instead -- visibly wrong on screen, which is the point: it names
     the bad string rather than crashing somewhere unrelated. *)
   try
      s := SysUtils.Format(aCFormat, aArgs);
   except
      on E: Exception do
         begin
         s := aCFormat;
         end;
   end;

   if Length(s) > CFORMAT_MAX_BYTES - 1 then
      begin
      SetLength(s, CFORMAT_MAX_BYTES - 1);
      end;

   if Length(s) > 0 then
      begin
      Move(s[1], aOutput^, Length(s));
      end;
   aOutput[Length(s)] := #0;
   Result := Length(s);
end;

end.

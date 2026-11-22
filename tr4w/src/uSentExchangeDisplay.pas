unit uSentExchangeDisplay;

(* THE EXCHANGE THE OPERATOR IS ABOUT TO SEND, AS THE MAIN WINDOW SHOWS IT --
  issue 355, NY4I 2026-11-21: "it would be very convenient if we could display
  the exchange I am supposed to send. That would have to come from the contest
  class."

  THE TEXT IS THE CONTEST'S. TContestBase.SentExchangeDisplayText states it;
  its default asks the contest's own ADIF STX_STRING getter
  (GetADIFSentExchange) for a probe QSO holding the next serial and the RST
  the program will send, so what the window shows and what the log exports
  are one statement and cannot drift. A contest whose on-air exchange carries
  something its exported string does not (Sweepstakes' own call) overrides.

  THIS UNIT IS THE PURE PART, with no LCL, no settings and no contest:
  - SqueezedExchangeText turns an exported string, whose widths are a column
    contract ('599 05     '), into one readable line;
  - SweepstakesSentDisplayText is the Sweepstakes line, '#123 U K1ABC 99 CT';
  - SentExchangeShown is whether the label shows at all.
  uTestSentExchangeDisplay pins each. *)

{$I tr4w.inc}

interface

(* aText with its leading and trailing blanks removed and every run of spaces
  and tabs inside it made one space (uCanonicalExchange.CollapseWhitespace).
  '' stays ''. *)
function SqueezedExchangeText(const aText: string): string;

(* THE SWEEPSTAKES EXCHANGE AS IT IS SENT: number, precedence, call, check,
  section -- '#123 U K1ABC 99 CT'. The number is written with a '#' so it
  cannot be read as the check. A part the station has not set is left out
  rather than shown as a gap, so an unset precedence reads '#123 K1ABC 99 CT'
  and the operator sees what is missing. A serial of 0 or less is not a
  number the program sends, and is left out too. *)
function SweepstakesSentDisplayText(const aSerial: integer;
                                    const aPrec, aCall, aCheck, aSection: string): string;

(* Whether the sent-exchange label shows: only when there is a text. A contest
  whose sent exchange cannot be stated simply answers '', and the label
  hides rather than show an empty box. *)
function SentExchangeShown(const aText: string): boolean;

implementation

uses
   SysUtils,
   (* CollapseWhitespace -- the squeeze the log's exchange_sent column
      already uses (uExchangeBuilder). One rule, not a second copy. A leaf:
      VC, SysUtils and StrUtils only. *)
   uCanonicalExchange;

function SqueezedExchangeText(const aText: string): string;
begin
   Result := CollapseWhitespace(aText);
end;

function SweepstakesSentDisplayText(const aSerial: integer;
                                    const aPrec, aCall, aCheck, aSection: string): string;
var
   line: string;
begin
   line := '';
   if aSerial > 0 then
      begin
      line := '#' + IntToStr(aSerial);
      end;
   line := line + ' ' + aPrec + ' ' + aCall + ' ' + aCheck + ' ' + aSection;
   Result := SqueezedExchangeText(line);
end;

function SentExchangeShown(const aText: string): boolean;
begin
   Result := SqueezedExchangeText(aText) <> '';
end;

end.

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
unit uCanonicalExchange;
{$I tr4w.inc}

(* THE SHARED PIECES OF A CANONICAL EXCHANGE -- M9a, 2026-10-02.

  WHAT A CANONICAL EXCHANGE IS. TR4W's parser accepts an exchange's fields
  in any order -- "EL88 1234" and "1234 EL88" both parse -- but a scoreboard
  (HamScore's RTC upload, the UDP contact broadcast) and the log's
  exchange_sent column want ONE spelling of each QSO. Each contest rebuilds
  its own from the QSO's typed fields: TContestBase.CanonicalReceivedExchange
  and CanonicalSentExchange.

  THIS UNIT IS THE PART THAT IS NOT A RULE. uExchangeBuilder held both: these
  helpers and a `case RXData.ceContest of` that named fourteen contests' field
  orders. The orders are each contest's own now; what is left here is how a
  default RST reads and how the CQ exchange template becomes what was sent --
  the same for every contest, called by the contests' own code (design 1.3: a
  helper is called by the class, never chosen for it).

  A LEAF: VC, SysUtils and StrUtils, and no global. A contest class may call
  it, and a test can without booting TR4W. Moved from uExchangeBuilder line
  for line; uExchangeBuilder keeps the two dispatchers, which read the
  session's settings and ask the QSO's contest. *)

interface

uses
   VC;

(* Runs of spaces and tabs become one space, and both ends are trimmed --
  applied to every canonical received exchange, after the template is filled
  in for a sent one, so the template's leading space and an absent optional
  field leave no trace. *)
function CollapseWhitespace(const s: string): string;

(* 599 on CW and digital, 59 on phone and FM -- what a received RST of 0
  means: the operator accepted the parser's default, and no explicit value
  was ever picked up. *)
function DefaultRST(aMode: ModeType): string;

(* The received RST as text: the QSO's own, else DefaultRST. *)
function RSTReceivedText(const aQso: ContestExchange): string;

(* WHAT WAS SENT, REBUILT FROM THE CQ EXCHANGE TEMPLATE -- the canonical sent
  exchange of every contest that has not said otherwise.

  '#' is our serial for this QSO, and the CW shorthand 5NN reads as 599: a
  scoreboard wants a numeric RST, not keyer shorthand. With no template
  configured the exchange as typed is the answer -- it still echoes the
  received exchange, but no worse than before the template was read, and it
  fabricates nothing. *)
function CanonicalFromCQTemplate(const aQso: ContestExchange;
                                 const aTemplate: string): string;

implementation

uses
   SysUtils,
   StrUtils;

function CollapseWhitespace(const s: string): string;
var
   i: integer;
   prevSpace: boolean;
begin
   Result := '';
   prevSpace := True;
   for i := 1 to Length(s) do
      begin
      if (s[i] = ' ') or (s[i] = #9) then
         begin
         if not prevSpace then
            begin
            Result := Result + ' ';
            prevSpace := True;
            end;
         end
      else
         begin
         Result := Result + s[i];
         prevSpace := False;
         end;
      end;
   while (Length(Result) > 0) and (Result[Length(Result)] = ' ') do
      begin
      SetLength(Result, Length(Result) - 1);
      end;
end;

function DefaultRST(aMode: ModeType): string;
begin
   case aMode of
      CW, Digital:
         begin
         Result := '599';
         end;
   else
      begin
      Result := '59';
      end;
   end;
end;

function RSTReceivedText(const aQso: ContestExchange): string;
begin
   if aQso.RSTReceived > 0 then
      begin
      Result := IntToStr(aQso.RSTReceived);
      end
   else
      begin
      Result := DefaultRST(aQso.Mode);
      end;
end;

function CanonicalFromCQTemplate(const aQso: ContestExchange;
                                 const aTemplate: string): string;
var
   tpl: string;
begin
   tpl := aTemplate;
   if tpl = '' then
      begin
      Result := Trim(string(aQso.ExchString));
      Exit;
      end;

   (* '#' -> our sent serial number for this QSO. *)
   tpl := StringReplace(tpl, '#', IntToStr(aQso.NumberSent), [rfReplaceAll]);
   (* CW shorthand '5NN' -> '599' (T = N in CW). *)
   tpl := StringReplace(tpl, '5NN', '599', [rfReplaceAll, rfIgnoreCase]);

   Result := CollapseWhitespace(tpl);
end;

end.

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

(* WHAT THE RECEIVED EXCHANGE HOLDS, IN WORDS -- issue 296, 2026-11-13.

  NY4I could not recall what the exchange field expected, and asked to see the
  expected exchange beside it. This is the WORDING, and only the wording: no
  LCL, so it is unit tested, and it says nothing about where the words are
  shown (a gray placeholder in the field, a tooltip, or a line below it --
  NY4I is choosing on screen).

  ONE RULE FOR EVERY CONTEST, from what the contest already states. A contest
  class marks the fields its received exchange carries
  (TContestBase.ReceivedExchangeFields, M11 S9a); each marked field has one
  phrase (the SExchangeHint resourcestrings in uAppStrings), and the phrases
  are joined as a list:
  "serial number and name" for the CW Open. No table names a contest.

  THE ORDER IS A FIXED ORDER, NOT THE ON-AIR ORDER. The field record does not
  say what order a contest sends its fields in, so the phrase says what to
  expect, not a format to type. The fixed order follows the helper names in
  uExchangeFields ("in the order an exchange is usually sent"): report,
  number, precedence, check, name, ... , QTH.

  NO WORDS RATHER THAN WRONG WORDS:
  - no contest, or one that marks no field: '';
  - a contest that accepts a blank exchange (General QSO, a log): '' -- it
    expects nothing, so there is nothing to remind the operator of;
  - a field with no phrase of its own (Kids, whose one flag stands for a
    whole multi-part exchange): '' for the whole hint, not a partial one.

  THE ZONE SLOT CAN HOLD A YEAR (issue 298): a contest that states a received
  year (ReceivedYearKind) keeps it where a zone goes, so its zone field reads
  "license year" -- or "years licensed" -- the rule TContestBase's
  ZoneColumnHeading uses for the log column. *)
unit uExchangeHint;

{$I tr4w.inc}

interface

uses
   VC,             (* ExchangeInformationRecord, TReceivedYearKind *)
   uContestBase;   (* TContestBase *)

(* The phrase for a field list. aYearKind says what the zone field holds. *)
function ExchangeHintText(const aFields: ExchangeInformationRecord;
                          aYearKind: TReceivedYearKind): string;

(* The phrase for a contest: '' for nil and for a contest that accepts a
   blank exchange, otherwise ExchangeHintText of its own field list. *)
function ContestExchangeHint(aContest: TContestBase): string;

implementation

uses
   SysUtils,      (* UnicodeFormat *)
   uAppStrings;   (* the SExchangeHint phrases *)

const
   (* Between the phrases before the last. Not a resourcestring: the
      catalogue tools drop an entry that is not language. *)
   HINT_SEPARATOR = ', ';

function ExchangeHintText(const aFields: ExchangeInformationRecord;
                          aYearKind: TReceivedYearKind): string;
var
   phrases: array of string;
   head: string;
   i: integer;

   procedure Add(aMarked: boolean; const aPhrase: string);
   begin
      if aMarked then
         begin
         SetLength(phrases, Length(phrases) + 1);
         phrases[High(phrases)] := aPhrase;
         end;
   end;

   function ZonePhrase: string;
   begin
      case aYearKind of
         rykNone:
            begin
            Result := SExchangeHintZone;
            end;
         rykYearsLicensed:
            begin
            Result := SExchangeHintYearsLicensed;
            end;
      else
         begin
         Result := SExchangeHintLicenseYear;
         end;
      end;
   end;

begin
   Result := '';

   (* A field with no phrase: no hint at all, rather than half of one. *)
   if aFields.Kids then
      begin
      Exit;
      end;

   phrases := nil;
   Add(aFields.RST,           SExchangeHintSignalReport);
   Add(aFields.QSONumber,     SExchangeHintSerialNumber);
   Add(aFields.Precedence,    SExchangeHintPrecedence);
   Add(aFields.Check,         SExchangeHintCheck);
   Add(aFields.Name,          SExchangeHintName);
   Add(aFields.Age,           SExchangeHintAge);
   Add(aFields.ClassEI,       SExchangeHintClass);
   Add(aFields.Chapter,       SExchangeHintChapter);
   Add(aFields.Power,         SExchangeHintPower);
   Add(aFields.Zone,          ZonePhrase);
   Add(aFields.ZoneOrSociety, SExchangeHintZoneOrSociety);
   Add(aFields.QTH,           SExchangeHintQTH);
   Add(aFields.TenTenNum,     SExchangeHintTenTenNumber);
   Add(aFields.FOCNumber,     SExchangeHintFOCNumber);
   Add(aFields.RandomChars,   SExchangeHintRandomChars);

   if Length(phrases) = 0 then
      begin
      Exit;
      end;

   if Length(phrases) = 1 then
      begin
      Result := phrases[0];
      Exit;
      end;

   head := phrases[0];
   for i := 1 to High(phrases) - 1 do
      begin
      head := head + HINT_SEPARATOR + phrases[i];
      end;
   Result := UnicodeFormat(SExchangeHintAnd, [head, phrases[High(phrases)]]);
end;

function ContestExchangeHint(aContest: TContestBase): string;
begin
   if aContest = nil then
      begin
      Result := '';
      end
   else if ContestAcceptsBlankExchange(aContest) then
      begin
      Result := '';
      end
   else
      begin
      Result := ExchangeHintText(aContest.ReceivedExchangeFields,
                                 aContest.ReceivedYearKind);
      end;
end;

end.

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

(* THE FIELDS A RECEIVED EXCHANGE CARRIES -- NAMED HELPERS, ONE PER FIELD
  SET. M11 S9a, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S9a; NY4I's
  ruling on Q92, option 2).

  WHAT IT REPLACES. LOGDUPE.SetUpExchangeInformation was a `case` over the
  session's exchange shape (ExchangeType) that marked the fields of
  ExchangeInformationRecord the shape carries -- one of the four
  exchange-shape machines. Each contest class now states its own field list
  (TContestBase.ReceivedExchangeFields), and states it by CALLING one of the
  helpers below. No enum selects a helper, and nothing here names a contest
  or an exchange shape (CONTEST_OWNERSHIP_DESIGN.md 1.3).

  ONE HELPER PER FIELD SET, NOT PER SHAPE. The registered contests run 51
  shapes; the machine's 39 live arms marked 27 distinct sets for 50 of them,
  and the 51st (RSTAndGridSquareOrRDA, the UA4W Championship) had no arm and
  marked nothing -- 28 sets with the empty one. The machine itself already
  grouped shapes with one set under one arm. A helper per shape would be the
  same body written up to ten times, which is the drift this tree's rule
  against copies exists to stop. So a helper is named for the fields it
  marks, in the order an exchange is usually sent.

  EACH BODY IS ITS ARM, AS IT STOOD. The UA4W Championship's empty list is
  transcribed, not fixed (plan F24). The machine's four arms no registered
  contest reached have no helper of their own (plan S9a); only one of them,
  CheckAndChapterOrQTH's Chapter-Check-QTH, marked a set no live arm did.

  THE ONE DIFFERENCE FROM THE MACHINE, AND WHY IT IS NOT A CHANGE. The
  machine cleared thirteen of the record's sixteen fields and left Kids,
  TenTenNum and FOCNumber as they were. Every helper starts from
  ExchangeFieldsNone, which clears all sixteen. The program assigns the
  record once, at start-up, over a zero-initialized global, so no run could
  see the difference (plan F24). *)
unit uExchangeFields;

{$I tr4w.inc}

interface

uses
   VC;

(* No field at all. *)
function ExchangeFieldsNone: ExchangeInformationRecord;

function ExchangeFieldsClassQTH: ExchangeInformationRecord;
function ExchangeFieldsKids: ExchangeInformationRecord;
function ExchangeFieldsNameQTH: ExchangeInformationRecord;
function ExchangeFieldsNameQTHTenTenNumber: ExchangeInformationRecord;
function ExchangeFieldsQSONumber: ExchangeInformationRecord;
function ExchangeFieldsQSONumberAge: ExchangeInformationRecord;
function ExchangeFieldsQSONumberName: ExchangeInformationRecord;
function ExchangeFieldsQSONumberNameChapterQTH: ExchangeInformationRecord;
function ExchangeFieldsQSONumberNameQTH: ExchangeInformationRecord;
function ExchangeFieldsQSONumberPrecedenceCheckQTH: ExchangeInformationRecord;
function ExchangeFieldsQSONumberQTH: ExchangeInformationRecord;
function ExchangeFieldsQSONumberZone: ExchangeInformationRecord;
function ExchangeFieldsQTH: ExchangeInformationRecord;
function ExchangeFieldsRSTAge: ExchangeInformationRecord;
function ExchangeFieldsRSTAgeQTH: ExchangeInformationRecord;
function ExchangeFieldsRSTNameQTH: ExchangeInformationRecord;
function ExchangeFieldsRSTPower: ExchangeInformationRecord;
function ExchangeFieldsRSTPrecedenceQTH: ExchangeInformationRecord;
function ExchangeFieldsRSTQSONumber: ExchangeInformationRecord;
function ExchangeFieldsRSTQSONumberQTH: ExchangeInformationRecord;
function ExchangeFieldsRSTQSONumberRandomChars: ExchangeInformationRecord;
function ExchangeFieldsRSTQSONumberZone: ExchangeInformationRecord;
function ExchangeFieldsRSTQTH: ExchangeInformationRecord;
function ExchangeFieldsRSTQTHNamePowerQSONumber: ExchangeInformationRecord;
function ExchangeFieldsRSTQTHPower: ExchangeInformationRecord;
function ExchangeFieldsRSTZone: ExchangeInformationRecord;
function ExchangeFieldsRSTZoneQTH: ExchangeInformationRecord;

(* THE MARKED FIELDS BY NAME, space-separated, in the record's own order --
   the contest matrix's `exchange.fields` line and the field-list pin test
   (uTestExchangeFields) both print it, so they cannot spell a set
   differently. '' when nothing is marked. *)
function ExchangeFieldsText(const aInfo: ExchangeInformationRecord): string;

(* THE LOG'S SWEEPSTAKES COLUMNS, FROM THE FIELD LIST -- M11 S9e part 1,
   2026-10-15 (plan F15/F15a). MainUnit.SetColumnsWidth asks both of the
   field list start-up assigned to LOGDUPE.ExchangeInformation; they were
   `ContestSession.Exchange = QSONumberPrecedenceCheckDomesticQTHExchange`.

   THE CHECK COLUMN IS THE CHECK FIELD: only the Sweepstakes set
   (ExchangeFieldsQSONumberPrecedenceCheckQTH) marks it, so this is the old
   test exactly.

   THE PRECEDENCE COLUMN IS NOT THE PRECEDENCE FIELD ALONE, ON PURPOSE. ALL
   JA's set (ExchangeFieldsRSTPrecedenceQTH) marks a precedence and no check,
   and its log never showed the column -- asking the field alone would show
   it, a behaviour change that is NY4I's to make (F15a). So it asks for the
   precedence AND the check: the old test's contests, Sweepstakes alone.
   Pinned for every contest at every roster station by
   uTestExchangeKindReaders. *)
function ExchangeFieldsShowPrecedenceColumn(const aInfo: ExchangeInformationRecord): boolean;
function ExchangeFieldsShowCheckColumn(const aInfo: ExchangeInformationRecord): boolean;

implementation

uses
   SysUtils;

function ExchangeFieldsNone: ExchangeInformationRecord;
begin
   Result := Default(ExchangeInformationRecord);
end;

(* ARRL and Winter Field Day: the class and the section. *)
function ExchangeFieldsClassQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.ClassEI := True;
   Result.QTH := True;
end;

function ExchangeFieldsKids: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.Kids := True;
end;

function ExchangeFieldsNameQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.Name := True;
   Result.QTH := True;
end;

function ExchangeFieldsNameQTHTenTenNumber: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.Name := True;
   Result.QTH := True;
   Result.TenTenNum := True;
end;

function ExchangeFieldsQSONumber: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
end;

function ExchangeFieldsQSONumberAge: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
   Result.Age := True;
end;

function ExchangeFieldsQSONumberName: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
   Result.Name := True;
end;

function ExchangeFieldsQSONumberNameChapterQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
   Result.Name := True;
   Result.Chapter := True;
   Result.QTH := True;
end;

function ExchangeFieldsQSONumberNameQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
   Result.Name := True;
   Result.QTH := True;
end;

(* The ARRL Sweepstakes: number, precedence, check and section. *)
function ExchangeFieldsQSONumberPrecedenceCheckQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
   Result.Precedence := True;
   Result.Check := True;
   Result.QTH := True;
end;

function ExchangeFieldsQSONumberQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
   Result.QTH := True;
end;

function ExchangeFieldsQSONumberZone: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QSONumber := True;
   Result.Zone := True;
end;

function ExchangeFieldsQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.QTH := True;
end;

function ExchangeFieldsRSTAge: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.Age := True;
end;

function ExchangeFieldsRSTAgeQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.Age := True;
   Result.QTH := True;
end;

function ExchangeFieldsRSTNameQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.Name := True;
   Result.QTH := True;
end;

function ExchangeFieldsRSTPower: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.Power := True;
end;

function ExchangeFieldsRSTPrecedenceQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.Precedence := True;
   Result.QTH := True;
end;

function ExchangeFieldsRSTQSONumber: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.QSONumber := True;
end;

function ExchangeFieldsRSTQSONumberQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.QSONumber := True;
   Result.QTH := True;
end;

function ExchangeFieldsRSTQSONumberRandomChars: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.QSONumber := True;
   Result.RandomChars := True;
end;

function ExchangeFieldsRSTQSONumberZone: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.QSONumber := True;
   Result.Zone := True;
end;

function ExchangeFieldsRSTQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.QTH := True;
end;

(* FISTS: the RST, the QTH, the name and the number or power. *)
function ExchangeFieldsRSTQTHNamePowerQSONumber: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.QTH := True;
   Result.Name := True;
   Result.Power := True;
   Result.QSONumber := True;
end;

function ExchangeFieldsRSTQTHPower: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.QTH := True;
   Result.Power := True;
end;

function ExchangeFieldsRSTZone: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.Zone := True;
end;

function ExchangeFieldsRSTZoneQTH: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
   Result.RST := True;
   Result.Zone := True;
   Result.QTH := True;
end;

function ExchangeFieldsText(const aInfo: ExchangeInformationRecord): string;

   procedure Add(aSet: boolean; const aName: string);
   begin
      if aSet then
         begin
         Result := Result + ' ' + aName;
         end;
   end;

begin
   Result := '';
   Add(aInfo.Age, 'Age');
   Add(aInfo.Chapter, 'Chapter');
   Add(aInfo.Check, 'Check');
   Add(aInfo.ClassEI, 'ClassEI');
   Add(aInfo.FOCNumber, 'FOCNumber');
   Add(aInfo.Kids, 'Kids');
   Add(aInfo.Name, 'Name');
   Add(aInfo.Power, 'Power');
   Add(aInfo.Precedence, 'Precedence');
   Add(aInfo.QSONumber, 'QSONumber');
   Add(aInfo.QTH, 'QTH');
   Add(aInfo.RandomChars, 'RandomChars');
   Add(aInfo.RST, 'RST');
   Add(aInfo.TenTenNum, 'TenTenNum');
   Add(aInfo.Zone, 'Zone');
   Add(aInfo.ZoneOrSociety, 'ZoneOrSociety');
   Result := Trim(Result);
end;

function ExchangeFieldsShowPrecedenceColumn(const aInfo: ExchangeInformationRecord): boolean;
begin
   (* Not ALL JA's precedence -- see the declaration. *)
   Result := aInfo.Precedence and aInfo.Check;
end;

function ExchangeFieldsShowCheckColumn(const aInfo: ExchangeInformationRecord): boolean;
begin
   Result := aInfo.Check;
end;

end.

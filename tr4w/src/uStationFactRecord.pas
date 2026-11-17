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

(* WHERE EACH STATION FACT LIVES ON A LOGGED QSO -- log schema 9 (NY4I,
  2026-11-17: "ALL MY_ VALUES GET WRITTEN TO THE QSO RECORD").

  WHY THIS UNIT EXISTS. Schema 3 gave the QSO row our station's grid, state,
  section, park, IOTA and zones, and left the name, Field Day class,
  Sweepstakes check and precedence, postal code and FOC number to be read from
  TODAY's settings at export -- "they do not change within a log". They do:
  a precedence corrected after logging rewrote what every earlier Sweepstakes
  QSO claimed to have sent. Nothing pointed at the omission, because nothing
  connected the list of station facts (uSettingsModel.TStationFact) to the
  list of my_* columns.

  STATION_FACT_IN_RECORD IS THAT CONNECTION. One row per TStationFact, so a
  fact added to the enumeration does not compile until someone says where a
  QSO keeps it -- or, with a reason, that it is not a per-QSO fact. The
  capture (uLogStore.LogStoreCurrentMyFacts) loops over it for the facts kept
  as typed, and uTestLogStationFacts drives every row.

  NOT A LEAF OF src\domain: it names the settings enumeration, and the domain
  units may not see uSettingsModel. It names no setting VALUE -- the caller
  hands those in -- so its rules are unit-tested without a session. *)
unit uStationFactRecord;

{$I tr4w.inc}

interface

uses
   uSettingsModel,   (* TStationFact *)
   uQsoMyFacts;      (* TQsoMyFacts -- the record the facts are written into *)

type
   (* HOW A QSO KEEPS ONE STATION FACT.

         sfkAsTyped     the resolved setting's text, verbatim, in the named
                        TQsoMyFacts field (RecordStationFactAsTyped)
         sfkAsSent      what the contest SENDS or derives from it, which is
                        not the typed text: MY ZONE is kept as the CQ zone
                        scoring uses (SessionMyCQZone), MY ITU ZONE as the
                        session's ITU zone, MY LICENSE YEAR as the year the
                        contest sends (year_sent, issue 300). The capture
                        handles each one by name.
         sfkNotPerQso   not kept on the QSO; Reason says why *)
   TStationFactKeeping = (sfkAsTyped, sfkAsSent, sfkNotPerQso);

   TStationFactInRecord = record
      Keeping: TStationFactKeeping;
      (* The qso column it lands in; '' only for sfkNotPerQso. *)
      Column: string;
      (* Why a fact is not per-QSO; '' otherwise. *)
      Reason: string;
   end;

const
   STATION_FACT_IN_RECORD: array[TStationFact] of TStationFactInRecord = (
      (* sfState *)      (Keeping: sfkAsTyped;   Column: 'my_state';       Reason: ''),
      (* sfSection *)    (Keeping: sfkAsTyped;   Column: 'my_section';     Reason: ''),
      (* sfZone *)       (Keeping: sfkAsSent;    Column: 'my_cq_zone';     Reason: ''),
      (* sfItuZone *)    (Keeping: sfkAsSent;    Column: 'my_itu_zone';    Reason: ''),
      (* sfGrid *)       (Keeping: sfkAsTyped;   Column: 'my_grid';        Reason: ''),
      (* sfName *)       (Keeping: sfkAsTyped;   Column: 'my_name';        Reason: ''),
      (* sfFdClass *)    (Keeping: sfkAsTyped;   Column: 'my_fd_class';    Reason: ''),
      (* sfCheck *)      (Keeping: sfkAsTyped;   Column: 'my_check';       Reason: ''),
      (* sfPrec *)       (Keeping: sfkAsTyped;   Column: 'my_prec';        Reason: ''),
      (* sfPark *)       (Keeping: sfkAsTyped;   Column: 'my_park';        Reason: ''),
      (* sfIota *)       (Keeping: sfkAsTyped;   Column: 'my_iota';        Reason: ''),
      (* sfPostalCode *) (Keeping: sfkAsTyped;   Column: 'my_postal_code'; Reason: ''),
      (* sfFocNumber *)  (Keeping: sfkAsTyped;   Column: 'my_foc_number';  Reason: ''),
      (* sfLicenseYear *)(Keeping: sfkAsSent;    Column: 'year_sent';      Reason: ''));

type
   (* ONE CORRECTION OF LOGGED QSOs -- schema 9 phase 2: the rows that sent
      OldText for Fact are to say NewText. Both as the column stores them
      (the resolved setting, UTF8Encoded: RecordStationFactAsTyped's form);
      '' is "none", which the column holds as NULL. Count is how many logged
      QSOs sent OldText (uLogStore.LogStoreCountQSOsSentStationValue). A
      RECORD BECAUSE IT IS AN INTERFACE PARAMETER: what Preferences hands
      uLogStore.LogStoreCorrectSentStation, no behaviour of its own. *)
   TStationFactCorrection = record
      Fact: TStationFact;
      OldText: AnsiString;
      NewText: AnsiString;
      Count: integer;
   end;
   TStationFactCorrections = array of TStationFactCorrection;

(* WRITE ONE sfkAsTyped FACT'S TEXT INTO aFacts -- aValue is the resolved
  setting (Settings.My.Resolved(aFact)), UTF8Encoded here: a name may be
  Cyrillic, and the record's fields are AnsiString. A fact that is not
  sfkAsTyped changes nothing. *)
procedure RecordStationFactAsTyped(var aFacts: TQsoMyFacts; aFact: TStationFact;
                                   const aValue: string);

(* THE TEXT aFacts HOLDS FOR ONE sfkAsTyped FACT, decoded -- the inverse of
  RecordStationFactAsTyped. '' for any other fact. *)
function StationFactAsTypedOf(const aFacts: TQsoMyFacts; aFact: TStationFact): string;

(* THE FIRST STATION VALUE AN EDIT QSO SAVE CHANGED THAT ITS FIELD'S RULE
  REFUSES -- '' when none, else the reason (uStationFieldCheck.
  StationFieldProblem, the rule Preferences > Station asks, so the two cannot
  disagree), with the fact and the typed text in aFact and aText.

  ONLY A CHANGED VALUE IS JUDGED, unlike the Station page's every-field rule:
  a QSO's row holds what it sent, and an old row holding a value today's rule
  would refuse (a one-digit check from before the rule) must not stop the
  operator correcting its grid. The kept-as-typed facts and the two zones are
  judged; the sent year has its own rule (ApplyEditedSentYear). *)
function EditedStationFactProblem(const aShown, aTyped: TQsoMyFacts;
                                  out aFact: TStationFact;
                                  out aText: string): string;

(* THE SAME QUESTION AS THE SENTENCE EDIT QSO SHOWS: '' when every changed
  value is acceptable, else SEditQSOStationValueRefused naming the value, the
  text and the reason. *)
function EditedStationFactRefusal(const aShown, aTyped: TQsoMyFacts): string;

(* A STATION FACT IN THE OPERATOR'S WORDS -- 'Precedence' for sfPrec. ONE
  answer, for the labels of Edit QSO's our-station group and for the lines of
  Preferences' "also this contest" and correction questions, so the two name
  a fact the same way. Translated (uAppStrings). *)
function StationFactCaption(aFact: TStationFact): string;

implementation

uses
   SysUtils,
   uAppStrings,          (* the captions *)
   uStationFieldCheck;   (* StationFieldProblem -- the one rule per field *)

function StationFactCaption(aFact: TStationFact): string;
begin
   case aFact of
      sfState:       Result := SEditQSOMyState;
      sfSection:     Result := SEditQSOMySection;
      sfZone:        Result := SEditQSOMyCQZone;
      sfItuZone:     Result := SEditQSOMyITUZone;
      sfGrid:        Result := SEditQSOMyGrid;
      sfName:        Result := SEditQSOMyName;
      sfFdClass:     Result := SEditQSOMyFdClass;
      sfCheck:       Result := SEditQSOMyCheck;
      sfPrec:        Result := SEditQSOMyPrec;
      sfPark:        Result := SEditQSOMyPark;
      sfIota:        Result := SEditQSOMyIota;
      sfPostalCode:  Result := SEditQSOMyPostalCode;
      sfFocNumber:   Result := SEditQSOMyFocNumber;
      sfLicenseYear: Result := SStationFactLicenseYear;
   end;
end;

(* A zone as the Station page types it: '' for 0, unknown. *)
function ZoneAsTyped(aZone: integer): string;
begin
   Result := '';
   if aZone > 0 then
      begin
      Result := IntToStr(aZone);
      end;
end;

(* The text aFacts holds for aFact as the operator types it -- the as-typed
  facts decoded, the two zones as numbers. '' for the sent year. *)
function TypedTextOf(const aFacts: TQsoMyFacts; aFact: TStationFact): string;
begin
   case aFact of
      sfZone:
         begin
         Result := ZoneAsTyped(aFacts.CQZone);
         end;
      sfItuZone:
         begin
         Result := ZoneAsTyped(aFacts.ITUZone);
         end;
   else
      begin
      Result := StationFactAsTypedOf(aFacts, aFact);
      end;
   end;
end;

function EditedStationFactRefusal(const aShown, aTyped: TQsoMyFacts): string;
var
   fact: TStationFact;
   text: string;
   problem: string;
begin
   (* See the declaration. *)
   Result := '';
   problem := EditedStationFactProblem(aShown, aTyped, fact, text);
   if problem <> '' then
      begin
      Result := UnicodeFormat(SEditQSOStationValueRefused,
                              [StationFactCaption(fact), text, problem]);
      end;
end;

function EditedStationFactProblem(const aShown, aTyped: TQsoMyFacts;
                                  out aFact: TStationFact;
                                  out aText: string): string;
var
   fact: TStationFact;
begin
   (* See the declaration. *)
   Result := '';
   aFact := Low(TStationFact);
   aText := '';
   for fact := Low(TStationFact) to High(TStationFact) do
      begin
      if fact = sfLicenseYear then
         begin
         Continue;
         end;
      if TypedTextOf(aTyped, fact) = TypedTextOf(aShown, fact) then
         begin
         Continue;
         end;
      Result := StationFieldProblem(StationFactCommand(fact), TypedTextOf(aTyped, fact));
      if Result <> '' then
         begin
         aFact := fact;
         aText := TypedTextOf(aTyped, fact);
         Exit;
         end;
      end;
end;

procedure RecordStationFactAsTyped(var aFacts: TQsoMyFacts; aFact: TStationFact;
                                   const aValue: string);
var
   text: AnsiString;
begin
   text := UTF8Encode(aValue);
   case aFact of
      sfState:
         begin
         aFacts.State := text;
         end;
      sfSection:
         begin
         aFacts.Section := text;
         end;
      sfGrid:
         begin
         aFacts.Grid := text;
         end;
      sfName:
         begin
         aFacts.Name := text;
         end;
      sfFdClass:
         begin
         aFacts.FdClass := text;
         end;
      sfCheck:
         begin
         aFacts.Check := text;
         end;
      sfPrec:
         begin
         aFacts.Prec := text;
         end;
      sfPark:
         begin
         aFacts.Park := text;
         end;
      sfIota:
         begin
         aFacts.Iota := text;
         end;
      sfPostalCode:
         begin
         aFacts.PostalCode := text;
         end;
      sfFocNumber:
         begin
         aFacts.FocNumber := text;
         end;
   else
      begin
      (* sfkAsSent or sfkNotPerQso: not this routine's. *)
      end;
   end;
end;

function StationFactAsTypedOf(const aFacts: TQsoMyFacts; aFact: TStationFact): string;
begin
   Result := '';
   case aFact of
      sfState:
         begin
         Result := UTF8Decode(aFacts.State);
         end;
      sfSection:
         begin
         Result := UTF8Decode(aFacts.Section);
         end;
      sfGrid:
         begin
         Result := UTF8Decode(aFacts.Grid);
         end;
      sfName:
         begin
         Result := UTF8Decode(aFacts.Name);
         end;
      sfFdClass:
         begin
         Result := UTF8Decode(aFacts.FdClass);
         end;
      sfCheck:
         begin
         Result := UTF8Decode(aFacts.Check);
         end;
      sfPrec:
         begin
         Result := UTF8Decode(aFacts.Prec);
         end;
      sfPark:
         begin
         Result := UTF8Decode(aFacts.Park);
         end;
      sfIota:
         begin
         Result := UTF8Decode(aFacts.Iota);
         end;
      sfPostalCode:
         begin
         Result := UTF8Decode(aFacts.PostalCode);
         end;
      sfFocNumber:
         begin
         Result := UTF8Decode(aFacts.FocNumber);
         end;
   else
      begin
      Result := '';
      end;
   end;
end;

end.

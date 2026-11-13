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

(* WHAT A STATION-PAGE EDIT OF MY LICENSE YEAR DOES TO THE OPEN CONTEST --
  issue 300 (NY4I confirmed the first answers 2026-11-12, the two below
  2026-11-13).

  The Station page edits the STATION's year (design 7.12). A contest that
  sends the year may state its own (the contest's override, uSettingsModel.
  TMySettings), and when it states none it follows the station. So an edit
  there could change what the open contest sends without the operator
  meaning it -- or fail to, when they did. When the open contest sends the
  year, Preferences asks which; this unit is the decision, so the rule is
  unit tested (uTestLicenseYearScope). The form asks and records.

  THE ANSWERS, SINCE LOG SCHEMA 8 (NY4I, 2026-11-13):
    lysStationOnly      the default (Enter and Escape). The contest keeps
                        sending what it sent: a stated year stays; a contest
                        that FOLLOWED the station is pinned to the year it was
                        following, or it would move with the edit.
    lysAlsoContest      the contest states the new year. Its LOGGED QSOs keep
                        the year each one sent (qso.year_sent): a QSO record
                        depends on nothing but its own row. THEN, when logged
                        QSOs sent the old year, a second question offers to
                        correct them, default No (LicenseYearCorrectionOf is
                        the rule; uLogStore.LogStoreCorrectSentYear the write;
                        SLicenseYearCorrectTitle/Body the text;
                        LicenseYearCorrectionAsks the gate the form asks).

  WHY THERE ARE TWO -- until schema 8 a QSO logged here did not record the
  year it sent, so its export followed the contest's current year, and the
  dialog's third answer, "this contest and its existing QSOs", was the same
  write as "also this contest" (measured, issue 300). Schema 8 stores the year
  per row, so the contest's year no longer reaches its logged QSOs except
  through the correction, and the third answer was retired with the form's
  move to two (issue 300 step 7).

  A LEAF ABOVE uSettingsModel and uContestBase's year rule: no form, no log
  write. *)
unit uLicenseYearChange;

{$I tr4w.inc}

interface

uses
   uSettingsModel,   (* TR4WSettings -- the station's year and the contest's *)
   VC,               (* TReceivedYearKind *)
   uContestBase;     (* SentLicenseYearValue -- the year sent *)

const
   (* The command the Station page edits and the log records. *)
   LICENSE_YEAR_COMMAND = 'MY LICENSE YEAR';

type
   TLicenseYearScope = (lysStationOnly, lysAlsoContest);

   (* THE CORRECTION OF LOGGED QSOs THE SECOND QUESTION OFFERS -- the year they
      sent (Old) and the year the contest sends now (New), each as the row
      stores it (uContestBase.SentLicenseYearValue); Known False is "none".
      A RECORD BECAUSE IT IS AN INTERFACE PARAMETER: what the form hands from
      this rule to uLogStore.LogStoreCorrectSentYear, no behaviour of its own. *)
   TLicenseYearCorrection = record
      OldKnown: boolean;
      OldValue: integer;
      NewKnown: boolean;
      NewValue: integer;
   end;

(* DOES A STATION-PAGE EDIT OF THE YEAR ASK? Only when the open contest sends
  the year (aContestSendsYear -- its ReceivedYearKind is not rykNone) and the
  station's value really changes; blanks around either do not count. *)
function LicenseYearEditAsks(aContestSendsYear: boolean;
                             const aOldStation, aNewStation: string): boolean;

(* APPLY THE ANSWER, AFTER the station's new year has been written into
  aSettings. aOldResolved is what the contest resolved to BEFORE that write
  (Settings.My.ResolvedLicenseYear, read first: once the station's value is
  written, a contest with no statement of its own already resolves to it).

  True when the contest's statement changed, which is the caller's cue to
  record it in the log (uLogStore.LogStoreRecordContestStatement). Written
  through TryOverrideForContest, so the setting's own check applies. *)
function ApplyLicenseYearScope(aSettings: TR4WSettings;
                               aScope: TLicenseYearScope;
                               const aOldResolved: string): boolean;

(* IS THERE A CORRECTION TO OFFER after the contest's year changed from
   aOldResolved to aNewResolved (the resolved MY LICENSE YEAR before and after,
   as ApplyLicenseYearScope's caller read them)? True when the contest sends a
   year (aKind not rykNone) and the two differ AS SENT -- '1964' and '64' are
   one two-digit year, so changing the spelling offers nothing. aCurrentYear is
   the calendar year the session reads a setting against
   (TStationContext.CurrentYear). The caller then asks the log how many QSOs
   sent the old year, and asks the operator only when there are some. *)
function LicenseYearCorrectionOf(aKind: TReceivedYearKind;
                                 const aOldResolved, aNewResolved: string;
                                 aCurrentYear: integer;
                                 out aCorrection: TLicenseYearCorrection): boolean;

(* DOES PREFERENCES ASK THE CORRECTION QUESTION? Only after "Also this contest"
   (aScope lysAlsoContest), when LicenseYearCorrectionOf offered a correction
   (aOffered), and when the log holds QSOs that sent the old year (aCount, from
   uLogStore.LogStoreCountQSOsSentYear: -1 is "the log could not be read",
   which asks nothing, like 0). *)
function LicenseYearCorrectionAsks(aScope: TLicenseYearScope; aOffered: boolean;
                                   aCount: integer): boolean;

implementation

uses
   SysUtils;

function LicenseYearEditAsks(aContestSendsYear: boolean;
                             const aOldStation, aNewStation: string): boolean;
begin
   Result := aContestSendsYear and (Trim(aOldStation) <> Trim(aNewStation));
end;

(* State aValue as the contest's year unless it already is exactly that. *)
function StateContestYear(aSettings: TR4WSettings; const aValue: string): boolean;
begin
   if aSettings.My.HasContestOverride(sfLicenseYear) and
      (aSettings.My.ContestOverride(sfLicenseYear) = aValue) then
      begin
      Result := False;
      Exit;
      end;
   Result := aSettings.TryOverrideForContest(LICENSE_YEAR_COMMAND, aValue);
end;

function ApplyLicenseYearScope(aSettings: TR4WSettings;
                               aScope: TLicenseYearScope;
                               const aOldResolved: string): boolean;
begin
   Result := False;
   if aSettings = nil then
      begin
      Exit;
      end;

   case aScope of
      lysStationOnly:
         begin
         (* A contest that stated its year is untouched by a station edit.
            One that followed the station keeps what it was following. *)
         if not aSettings.My.HasContestOverride(sfLicenseYear) then
            begin
            Result := StateContestYear(aSettings, Trim(aOldResolved));
            end;
         end;
      lysAlsoContest:
         begin
         (* The contest only. Its logged QSOs keep the year each sent; the
            correction question is the caller's (see the header). *)
         Result := StateContestYear(aSettings, Trim(aSettings.My.LicenseYear));
         end;
   end;
end;

function LicenseYearCorrectionOf(aKind: TReceivedYearKind;
                                 const aOldResolved, aNewResolved: string;
                                 aCurrentYear: integer;
                                 out aCorrection: TLicenseYearCorrection): boolean;
begin
   (* See the declaration. *)
   aCorrection.OldKnown := SentLicenseYearValue(aKind, aOldResolved, aCurrentYear,
                                                aCorrection.OldValue);
   aCorrection.NewKnown := SentLicenseYearValue(aKind, aNewResolved, aCurrentYear,
                                                aCorrection.NewValue);
   Result := (aKind <> rykNone) and
             ((aCorrection.OldKnown <> aCorrection.NewKnown) or
              (aCorrection.OldKnown and (aCorrection.OldValue <> aCorrection.NewValue)));
end;

function LicenseYearCorrectionAsks(aScope: TLicenseYearScope; aOffered: boolean;
                                   aCount: integer): boolean;
begin
   (* See the declaration. *)
   Result := (aScope = lysAlsoContest) and aOffered and (aCount > 0);
end;

end.

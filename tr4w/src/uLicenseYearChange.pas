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
  issue 300 (NY4I confirmed the three answers, 2026-11-12).

  The Station page edits the STATION's year (design 7.12). A contest that
  sends the year may state its own (the contest's override, uSettingsModel.
  TMySettings), and when it states none it follows the station. So an edit
  there could change what the open contest sends without the operator
  meaning it -- or fail to, when they did. When the open contest sends the
  year, Preferences asks which; this unit is the decision, so the rule is
  unit tested (uTestLicenseYearScope). The form asks and records.

  THE THREE ANSWERS:
    lysStationOnly      the default (Enter and Escape). The contest keeps
                        sending what it sent: a stated year stays; a contest
                        that FOLLOWED the station is pinned to the year it was
                        following, or it would move with the edit.
    lysAlsoContest      the contest states the new year.
    lysContestAndQSOs   the same write. SEE BELOW.

  WHY THE LAST TWO ARE ONE WRITE -- measured, not chosen (issue 300 report).
  A QSO logged here does not record the year it sent. Its my_* columns
  (uQsoMyFacts) hold no year, my_cq_zone is the CTY zone since issue 298, and
  for a year contest the export keeps the SESSION's sent text in the zone's
  slot (uContestBase.SentZoneKindOfQSO answers szkStatedMyZone, so
  MyStationExchangeOfQSO overlays nothing). Every logged row therefore exports
  the contest's CURRENT year: changing the contest's year changes what its
  existing QSOs export, whichever button said so. exchange_sent holds the
  text as sent, but it is insert-only and is read back only for an imported
  row. Keeping "this contest but not its existing QSOs" apart needs a per-row
  year, which is a schema decision for NY4I, not this unit's.

  A LEAF ABOVE uSettingsModel: no form, no log write. *)
unit uLicenseYearChange;

{$I tr4w.inc}

interface

uses
   uSettingsModel;   (* TR4WSettings -- the station's year and the contest's *)

const
   (* The command the Station page edits and the log records. *)
   LICENSE_YEAR_COMMAND = 'MY LICENSE YEAR';

type
   TLicenseYearScope = (lysStationOnly, lysAlsoContest, lysContestAndQSOs);

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
      lysAlsoContest, lysContestAndQSOs:
         begin
         (* ONE WRITE FOR BOTH -- see the header: a logged row records no
            year, so its export follows the contest's either way. *)
         Result := StateContestYear(aSettings, Trim(aSettings.My.LicenseYear));
         end;
   end;
end;

end.

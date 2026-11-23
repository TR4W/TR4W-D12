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

(* WHAT A STATION-PAGE EDIT DOES TO THE OPEN CONTEST, FOR ANY STATION VALUE --
  log schema 9, phase 2 (2026-11-17). The generalisation of issue 300's
  license-year rule (uLicenseYearChange, which now calls this).

  THE BENCH FINDING. A contest states its own station values at New Contest
  (design 7.12: Settings.My.SetContestOverride; the contest's value wins over
  the station's). The Station page edits the STATION's default. So a wrong MY
  PREC stated at New Contest could not be corrected from the UI at all: the
  edit changed the default, and Sweepstakes kept sending the stated one.
  Issue 300 had solved exactly this for MY LICENSE YEAR; nothing else had it.

  THE RULE, for every station value (TStationFact):

    WHEN IT ASKS    the station's value really changed (blanks around it are
                    ignored) AND the open contest USES the value
                    (uContestBase.ContestUsesStationFact: its New Contest
                    prompts ask for it; for the license year, it sends one).
                    A value the contest does not use follows the station as
                    it always has, and asks nothing.
    ONE QUESTION    per Save, listing every value that asks (Preferences;
                    NY4I dislikes a pile of modal boxes). One answer for all.
    sfsStationOnly  the default (Enter and Escape). The contest keeps what it
                    used: a stated value stays; a value the contest FOLLOWED
                    from the station is pinned to what it was following, or
                    it would move with the edit.
    sfsAlsoContest  the contest states the new value -- through
                    TR4WSettings.TryOverrideForContest, so the setting's own
                    check applies -- and the caller records the statement in
                    the log. Logged QSOs keep what they sent (schema 9: the
                    value is on the row); a SECOND question, default No, may
                    then correct them (StationFactCorrectionOf, below).

  WHERE THE CORRECTION MAKES SENSE (NY4I, 2026-11-13: a QSO sent what it
  sent; correcting is for a mistake only): a value the row keeps AS TYPED
  (uStationFactRecord, sfkAsTyped) -- the rows that hold exactly the old text
  are given the new. NOT the two zones: they are kept as the zone scoring
  uses, not as typed, and no contest prompts for the ITU zone. The license
  year keeps its own correction (uLicenseYearChange.LicenseYearCorrectionOf),
  because a year is compared AS SENT ('1964' and '64' are one year).

  A LEAF ABOVE uSettingsModel and uContestBase: no form, no log write. *)
unit uStationFactChange;

{$I tr4w.inc}

interface

uses
   uSettingsModel,      (* TR4WSettings, TStationFact *)
   uContestBase,        (* TContestBase, ContestUsesStationFact *)
   uStationFactRecord;  (* TStationFactCorrection *)

type
   TStationFactScope = (sfsStationOnly, sfsAlsoContest);
   TStationFacts = set of TStationFact;

   (* EVERY STATION VALUE AS IT STOOD BEFORE THE STATION PAGE WROTE -- the
      station's own, and what the open contest resolved to (its statement,
      or the station's). Taken BEFORE the write: once the station's value is
      written, a contest with no statement of its own already resolves to
      it, and the value it followed is lost. *)
   TStationFactsBefore = class
   private
      FStation: array[TStationFact] of string;
      FResolved: array[TStationFact] of string;
   public
      constructor Create(aSettings: TR4WSettings);
      function Station(aFact: TStationFact): string;
      function Resolved(aFact: TStationFact): string;
   end;

   (* WHAT THE STATION PAGE SHOWS FOR EACH VALUE, AND WHETHER IT IS THE
      CONTEST'S -- the bench finding of 2026-11-17 (NY4I, ARRL-SS-SSB).

      THE DEFECT. The contest stated MY PREC = U and MY CHECK = 80 at New
      Contest; an earlier Preferences save had made the station's default B.
      The page loaded the STATION's B, the contest sent U, and because the box
      already held B, OK changed nothing and asked nothing: the contest's
      value could be neither seen nor changed, under a heading reading
      "Contest exchange".

      THE RULE. While the open contest states a value of its own
      (Settings.My.HasContestOverride), the page SHOWS that value -- what the
      contest sends -- and Save compares the box against what was SHOWN, not
      against the station's default:
        unchanged   nothing is written (writing it would copy the contest's
                    value into the station's default)
        changed     the station's default is written as before, and the value
                    is asked about (StationFactsToAskOnPage) whether or not
                    the station's default moved -- typing B over a shown U
                    when the default already is B must still reach the
                    contest
      A value the contest does not state is shown as the station's, exactly
      as before, so with no contest open, or a contest that stated nothing,
      nothing changes. After a Save the page shows what is now in force
      (Refresh): the contest's value where it states one -- so "Station
      default only" puts the contest's value back in the box, and the
      question says so beforehand. *)
   TStationFactsShown = class
   private
      FShowsContest: array[TStationFact] of boolean;
      FShown: array[TStationFact] of string;
   public
      (* WHAT THE PAGE SHOWS FOR aFact, recorded: the contest's value when it
         states one, else aStationText -- the station's value as the page
         renders it. Answers the text to put in the box. *)
      function Take(aSettings: TR4WSettings; aFact: TStationFact;
                    const aStationText: string): string;
      function ShowsContest(aFact: TStationFact): boolean;
      function Shown(aFact: TStationFact): string;
      (* Did the operator change what the page showed? Blanks do not count. *)
      function Changed(aFact: TStationFact; const aTyped: string): boolean;
      (* SHOULD THE SAVE WRITE THE STATION'S DEFAULT FROM THIS BOX? Not when
         the box still holds the contest's value it was loaded with. *)
      function WritesStation(aFact: TStationFact; const aTyped: string): boolean;
      (* The values the page shows as the contest's that differ from the
         station's default -- the note under the page lists them. *)
      function DifferingFromStation(aSettings: TR4WSettings): TStationFacts;
   end;

(* THE VALUES ONE SAVE ASKS ABOUT, ON A PAGE THAT SHOWS THE CONTEST'S VALUES:
  StationFactsToAsk (the station's default changed and the contest uses it)
  plus aShownChanged, every value shown as the contest's whose box the
  operator changed (TStationFactsShown.ShowsContest and .Changed). *)
function StationFactsToAskOnPage(aBefore: TStationFactsBefore; aSettings: TR4WSettings;
                                 aContest: TContestBase;
                                 aShownChanged: TStationFacts): TStationFacts;

(* DOES A STATION-PAGE EDIT OF ONE VALUE ASK? Only when the open contest uses
  it (aContestUses) and the station's value really changes; blanks around
  either do not count. *)
function StationFactEditAsks(aContestUses: boolean;
                             const aOldStation, aNewStation: string): boolean;

(* THE VALUES ONE SAVE ASKS ABOUT: each fact whose station value changed
  between aBefore and aSettings and that aContest uses. *)
function StationFactsToAsk(aBefore: TStationFactsBefore; aSettings: TR4WSettings;
                           aContest: TContestBase): TStationFacts;

(* APPLY THE ANSWER FOR ONE VALUE, AFTER the station's new value has been
  written into aSettings. aOldResolved is what the contest resolved to before
  that write (TStationFactsBefore.Resolved). True when the contest's
  statement changed, the caller's cue to record it in the log
  (uLogStore.LogStoreRecordContestStatement with StationFactCommand). *)
function ApplyStationFactScope(aSettings: TR4WSettings; aFact: TStationFact;
                               aScope: TStationFactScope;
                               const aOldResolved: string): boolean;

(* IS THERE A CORRECTION OF LOGGED QSOs TO OFFER after the contest's value of
  aFact moved from aOldResolved to aNewResolved? Only for a value kept AS
  TYPED (see the header), and only when the two differ. aCorrection carries
  both as the column stores them; its Count is 0 -- the caller asks the log
  (uLogStore.LogStoreCountQSOsSentStationValue). *)
function StationFactCorrectionOf(aFact: TStationFact;
                                 const aOldResolved, aNewResolved: string;
                                 out aCorrection: TStationFactCorrection): boolean;

(* MAY A SCORING RULE READ THIS VALUE OFF A LOGGED QSO? True for the values
  schema 3 kept for scoring and the ADIF MY_ tags (state, section, grid, park,
  IOTA, the zones); False for the six schema 9 added -- name, FD class,
  check, precedence, postal code and FOC number are read only by the sent-
  exchange formatters and the CW messages (grep, 2026-11-17; the schema plan
  12n) -- for schema 14's prefecture and power class, which no scoring rule
  reads either -- and for the sent license year. A correction of a True one is
  followed by a rescore. *)
function StationFactFeedsScoring(aFact: TStationFact): boolean;

(* DOES PREFERENCES ASK THE CORRECTION QUESTION? Only after "Also this
  contest", when a correction was offered (aOffered) and the log holds QSOs
  that sent the old value (aCount: -1 is "the log could not be read", which
  asks nothing, like 0). *)
function StationCorrectionAsks(aScope: TStationFactScope; aOffered: boolean;
                               aCount: integer): boolean;

implementation

uses
   SysUtils;

constructor TStationFactsBefore.Create(aSettings: TR4WSettings);
var
   fact: TStationFact;
begin
   inherited Create;
   for fact := Low(TStationFact) to High(TStationFact) do
      begin
      FStation[fact] := '';
      FResolved[fact] := '';
      if aSettings <> nil then
         begin
         FStation[fact] := aSettings.My.StationValue(fact);
         FResolved[fact] := aSettings.My.Resolved(fact);
         end;
      end;
end;

function TStationFactsBefore.Station(aFact: TStationFact): string;
begin
   Result := FStation[aFact];
end;

function TStationFactsBefore.Resolved(aFact: TStationFact): string;
begin
   Result := FResolved[aFact];
end;

function TStationFactsShown.Take(aSettings: TR4WSettings; aFact: TStationFact;
                                 const aStationText: string): string;
begin
   FShowsContest[aFact] := (aSettings <> nil) and aSettings.My.HasContestOverride(aFact);
   if FShowsContest[aFact] then
      begin
      FShown[aFact] := aSettings.My.ContestOverride(aFact);
      end
   else
      begin
      FShown[aFact] := aStationText;
      end;
   Result := FShown[aFact];
end;

function TStationFactsShown.ShowsContest(aFact: TStationFact): boolean;
begin
   Result := FShowsContest[aFact];
end;

function TStationFactsShown.Shown(aFact: TStationFact): string;
begin
   Result := FShown[aFact];
end;

function TStationFactsShown.Changed(aFact: TStationFact; const aTyped: string): boolean;
begin
   Result := Trim(aTyped) <> Trim(FShown[aFact]);
end;

function TStationFactsShown.WritesStation(aFact: TStationFact; const aTyped: string): boolean;
begin
   Result := (not FShowsContest[aFact]) or Changed(aFact, aTyped);
end;

function TStationFactsShown.DifferingFromStation(aSettings: TR4WSettings): TStationFacts;
var
   fact: TStationFact;
begin
   Result := [];
   if aSettings = nil then
      begin
      Exit;
      end;
   for fact := Low(TStationFact) to High(TStationFact) do
      begin
      if FShowsContest[fact] and
         (Trim(FShown[fact]) <> Trim(aSettings.My.StationValue(fact))) then
         begin
         Include(Result, fact);
         end;
      end;
end;

function StationFactsToAskOnPage(aBefore: TStationFactsBefore; aSettings: TR4WSettings;
                                 aContest: TContestBase;
                                 aShownChanged: TStationFacts): TStationFacts;
begin
   (* See the declaration. *)
   Result := StationFactsToAsk(aBefore, aSettings, aContest) + aShownChanged;
end;

function StationFactEditAsks(aContestUses: boolean;
                             const aOldStation, aNewStation: string): boolean;
begin
   Result := aContestUses and (Trim(aOldStation) <> Trim(aNewStation));
end;

function StationFactsToAsk(aBefore: TStationFactsBefore; aSettings: TR4WSettings;
                           aContest: TContestBase): TStationFacts;
var
   fact: TStationFact;
begin
   Result := [];
   if (aBefore = nil) or (aSettings = nil) then
      begin
      Exit;
      end;
   for fact := Low(TStationFact) to High(TStationFact) do
      begin
      (* The cheap comparison first: asking the contest builds its prompts. *)
      if Trim(aBefore.Station(fact)) = Trim(aSettings.My.StationValue(fact)) then
         begin
         Continue;
         end;
      if StationFactEditAsks(ContestUsesStationFact(aContest, fact),
                             aBefore.Station(fact),
                             aSettings.My.StationValue(fact)) then
         begin
         Include(Result, fact);
         end;
      end;
end;

(* State aValue as the contest's value of aFact unless it already is exactly
  that. *)
function StateContestValue(aSettings: TR4WSettings; aFact: TStationFact;
                           const aValue: string): boolean;
begin
   if aSettings.My.HasContestOverride(aFact) and
      (aSettings.My.ContestOverride(aFact) = aValue) then
      begin
      Result := False;
      Exit;
      end;
   Result := aSettings.TryOverrideForContest(StationFactCommand(aFact), aValue);
end;

function ApplyStationFactScope(aSettings: TR4WSettings; aFact: TStationFact;
                               aScope: TStationFactScope;
                               const aOldResolved: string): boolean;
begin
   Result := False;
   if aSettings = nil then
      begin
      Exit;
      end;

   case aScope of
      sfsStationOnly:
         begin
         (* A contest that stated its value is untouched by a station edit.
            One that followed the station keeps what it was following. *)
         if not aSettings.My.HasContestOverride(aFact) then
            begin
            Result := StateContestValue(aSettings, aFact, Trim(aOldResolved));
            end;
         end;
      sfsAlsoContest:
         begin
         (* The contest only. Its logged QSOs keep what each sent; the
            correction question is the caller's (see the header). *)
         Result := StateContestValue(aSettings, aFact,
                                     Trim(aSettings.My.StationValue(aFact)));
         end;
   end;
end;

function StationFactCorrectionOf(aFact: TStationFact;
                                 const aOldResolved, aNewResolved: string;
                                 out aCorrection: TStationFactCorrection): boolean;
begin
   (* See the declaration. As RecordStationFactAsTyped stores them, so the
      old text matches the column byte for byte. *)
   aCorrection.Fact := aFact;
   aCorrection.OldText := UTF8Encode(aOldResolved);
   aCorrection.NewText := UTF8Encode(aNewResolved);
   aCorrection.Count := 0;
   Result := (STATION_FACT_IN_RECORD[aFact].Keeping = sfkAsTyped) and
             (aCorrection.OldText <> aCorrection.NewText);
end;

function StationFactFeedsScoring(aFact: TStationFact): boolean;
begin
   (* See the declaration. *)
   Result := not (aFact in [sfName, sfFdClass, sfCheck, sfPrec, sfPostalCode,
                            sfFocNumber, sfLicenseYear, sfPrefecture,
                            sfPowerClass]);
end;

function StationCorrectionAsks(aScope: TStationFactScope; aOffered: boolean;
                               aCount: integer): boolean;
begin
   (* See the declaration. *)
   Result := (aScope = sfsAlsoContest) and aOffered and (aCount > 0);
end;

end.
